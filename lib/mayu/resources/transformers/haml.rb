# typed: strict
# frozen_string_literal: true

require "bundler/setup"
require "syntax_tree"
require "syntax_tree/haml"
require "haml"
require "console"
require_relative "css"

module Mayu
  module Resources
    module Transformers
      module Haml
        class TransformResult < T::Struct
          const :filename, String
          const :output, String
          const :content_hash, String
          const :css, T.nilable(CSS::TransformResult)
          const :source_map, T::Hash[String, T.untyped]
        end

        extend T::Sig

        sig do
          params(
            source: String,
            source_path: String,
            source_line: Integer,
            content_hash: T.nilable(String),
            elements_to_classes: T::Boolean
          ).returns(TransformResult)
        end
        def self.transform(
          source:,
          source_path:,
          source_line: 1,
          content_hash: nil,
          elements_to_classes: true
        )
          source_path_without_extension =
            File.join(
              File.dirname(source_path),
              File.basename(source_path, ".*")
            ).delete_prefix("./")

          ast = SyntaxTree::Haml.parse(source)
          out = StringIO.new
          transformer =
            Transformer.new(
              out,
              source_path_without_extension,
              elements_to_classes:
            )
          transformer.visit(ast)
          output = out.tap(&:rewind).read.to_s

          TransformResult.new(
            output:,
            filename: source_path,
            css: transformer.css,
            content_hash: Digest::SHA256.digest(output),
            source_map: {
            }
          )
        end

        class ExtractNameParserVisitor < SyntaxTree::Visitor
          extend T::Sig

          sig { returns(T.nilable(String)) }
          attr_reader :name

          sig { void }
          def initialize
            @name = T.let(nil, T.nilable(String))
          end

          sig { params(node: SyntaxTree::HashLiteral).void }
          def visit_hash(node)
            node.assocs.each do |child|
              case child.key
              when SyntaxTree::StringLiteral
                key = child.key.parts.first.value

                case key
                when "name"
                  @name = child.value.value.value
                else
                  raise "Invalid attribute #{key.inspect}"
                end
              when SyntaxTree::Label
                case key = child.key.value
                when "name:"
                  @name = child.value.value.value
                else
                  raise "Invalid attribute #{key.inspect}"
                end
              else
                raise "Invalid key type: #{child.key.inspect}"
              end
            end
          end
        end

        class HashParserVisitor < SyntaxTree::Visitor
          extend T::Sig

          sig { void }
          def initialize
            @hash = T.let({}, T::Hash[Symbol, T.untyped])
            @klass = T.let(nil, T.nilable(SyntaxTree::Node))
            @length = T.let(0, Integer)
            @parser = T.let(nil, T.nilable(SyntaxTree::Parser))
          end

          sig { returns(T.nilable(SyntaxTree::Node)) }
          attr_reader :klass
          sig { returns(Integer) }
          attr_reader :length

          sig { params(node: SyntaxTree::HashLiteral).void }
          def visit_hash(node)
            @length =
              node
                .assocs
                .delete_if do |child|
                  next false if child.is_a?(SyntaxTree::AssocSplat)

                  case child.key
                  when SyntaxTree::StringLiteral
                    key = child.key.parts.first.value

                    case key
                    when "class"
                      set_klass(child.value)
                      true
                    when /\Aon/
                      child.instance_variable_set(
                        :@key,
                        SyntaxTree::Label.new(
                          value: "#{key.tr("-", "_")}:",
                          location: child.key.location
                        )
                      )
                      child.instance_variable_set(
                        :@value,
                        SyntaxTree::CallNode.new(
                          receiver: nil,
                          operator: nil,
                          message:
                            SyntaxTree::Ident.new(
                              value: "handler",
                              location: child.value.location
                            ),
                          arguments:
                            SyntaxTree::ArgParen.new(
                              location: child.value.location,
                              arguments:
                                SyntaxTree::Args.new(
                                  location: child.value.location,
                                  parts: [
                                    SyntaxTree::SymbolLiteral.new(
                                      value: child.value,
                                      location: child.value.location
                                    )
                                  ]
                                )
                            ),
                          location: child.value.location
                        )
                      )
                      false
                    else
                      # TODO: Is there a better way to transform the tree,
                      # than with instance_variable_set?
                      # This is supposed to convert string keys into symbols.
                      child.instance_variable_set(
                        :@key,
                        SyntaxTree::Label.new(
                          value: "#{key.tr("-", "_")}:",
                          location: child.key.location
                        )
                      )
                      false
                    end
                  when SyntaxTree::Label
                    if child.key.value == "class:"
                      set_klass(child.value)
                      true
                    else
                      false
                    end
                  else
                    raise NotImplementedError, "This case needs to be handled"
                  end
                end
                .length
          end

          sig { params(node: SyntaxTree::Statements).void }
          def visit_statements(node)
            @parser = node.parser
            super
          end

          sig { params(node: SyntaxTree::Node).void }
          def set_klass(node)
            @klass =
              SyntaxTree::Program.new(
                statements:
                  SyntaxTree::Statements.new(
                    T.must(@parser),
                    body: [node],
                    location: node.location
                  ),
                location: node.location
              )
          end

          sig { params(method: Symbol, node: T.untyped).void }
          def method_missing(method, node)
            Console.logger.error("#{self.class.name}##{__method__}", <<~EOF)
            Please implement the following method:

            sig { params(node: ::#{node.class.name}).void }
            def #{method}(node)
            end
            EOF
          end
        end

        class Transformer < SyntaxTree::Haml::Visitor
          extend T::Sig

          CREATE_ELEMENT_FN = T.let("Mayu::VDOM.h", String)
          ADD_SPACE_LEFT = :nuke_inner_whitespace
          ADD_SPACE_RIGHT = :nuke_outer_whitespace

          sig { returns(T.nilable(CSS::TransformResult)) }
          attr_reader :css

          sig do
            params(
              out: StringIO,
              path: String,
              elements_to_classes: T::Boolean
            ).void
          end
          def initialize(out, path, elements_to_classes: true)
            @out = out
            @path = path
            @elements_to_classes = elements_to_classes
            @level = T.let(0, Integer)
            @css = T.let(nil, T.nilable(CSS::TransformResult))
          end

          sig { params(block: T.proc.void).void }
          def indent(&block)
            @level += 1
            yield
          ensure
            @level -= 1
          end

          sig { returns(String) }
          def indentation
            "  " * @level
          end

          sig { params(node: T.untyped).returns(T.untyped) }
          def visit(node)
            super
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_root(node)
            if node.children[0].type == :filter &&
                 node.children[0].value[:name] == "ruby"
              visit(node.children.shift)
            end

            if node.children[0].type == :filter &&
                 node.children[0].value[:name] == "css"
              visit(node.children.shift)
            end

            @out << indentation << "public def render\n"

            indent do
              node.children.each_with_index do |child, i|
                @out << "\n" unless i.zero?
                @out << indentation
                visit(child)
              end
            end

            @out << "\nend\n"
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_haml_comment(node)
            @out << "\n" << indentation
            @out << "# comment\n"
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_filter(node)
            return if node.value[:text].to_s.strip.empty?

            case node.value
            in { name: "ruby", text: }
              @out << text.gsub(/^/, indentation)
            in { name: "plain", text: }
              @out << text.inspect
            in { name: "css", text: }
              raise "CSS has already been set" if @css

              @css =
                CSS.transform(
                  source: text,
                  source_path: @path + ".haml (inline)",
                  content_hash: Digest::SHA256.hexdigest(text)[0..7].to_s
                )
            end
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_slot(node)
            @out << indentation

            @out << "Mayu::VDOM.slot(children"

            node.value[:attributes].each do |attr, value|
              unless attr == "name"
                raise ArgumentError,
                      "The slot tag only accepts the attribute name, given: #{attr.inspect}"
              end

              @out << ", " << value.inspect
            end

            if dynamic_attributes = node.value[:dynamic_attributes]
              if new = dynamic_attributes.new
                # TODO: Better parse new as Ruby..
                ast = SyntaxTree.parse(new)
                visitor = ExtractNameParserVisitor.new
                visitor.visit(ast)
                if name = visitor.name
                  @out << ", #{name}"
                end
              end
            end

            @out << ")"

            children = node.children.reject { _1.type == :haml_comment }

            case children
            in []
              # noop
            in [child]
              @out << " || begin\n"
              indent { visit(child) }
              @out << "\n" << indentation << "end"
            else
              raise "<slot> only allows 0 or 1 children"
            end
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_tag(node)
            name = node.value.fetch(:name)

            return visit_slot(node) if name == "slot"

            @out << indentation
            @out << "#{CREATE_ELEMENT_FN}("

            if name[0].downcase == name[0]
              @out << name.to_sym.inspect
            else
              @out << name
            end

            old_pos = @out.pos

            indent do
              if value = node.value[:value]
                unless value.empty?
                  @out << ",\n" << indentation

                  if node.value[:parse]
                    @out << "(#{value})"
                  else
                    @out << "#{value.inspect}"
                  end
                end
              end

              transform_children(node, node.children).each do |child|
                @out << ",\n"
                visit(child)
              end
            end

            indent { visit_node_attributes(node) }

            @out << "\n" << indentation unless @out.pos == old_pos

            @out << ")"
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_node_attributes(node)
            classes =
              T.let([], T::Array[T.any(String, Symbol, SyntaxTree::Node)])

            classes.push(:"__#{node.value[:name]}") if @elements_to_classes

            node.value[:attributes].each do |attr, value|
              if attr == "class"
                classes.push(*value.split.map(&:to_sym))
                next
              end

              @out << ",\n"
              @out << indentation

              @out << "#{attr.tr("-", "_")}: #{value.inspect}"
            end

            if dynamic_attributes = node.value[:dynamic_attributes]
              if new = dynamic_attributes.new
                visit_dynamic_attribute(new) { |klass| classes << klass }
              end

              if old = dynamic_attributes.old
                visit_dynamic_attribute(old) { |klass| classes << klass }
              end
            end

            unless classes.empty?
              @out << ",\n"
              @out << indentation
              @out << "class: styles["
              classes.each_with_index do |klass, i|
                @out << ", " unless i.zero?
                case klass
                when SyntaxTree::Node
                  @out << format_ruby_ast(klass)
                else
                  @out << klass.inspect
                end
              end
              @out << "]"
            end

            if object_ref = node.value[:object_ref]
              if object_ref != :nil
                @out << ",\n"
                @out << indentation
                @out << "key: #{object_ref}.inspect"
              end
            end
          end

          sig do
            params(
              parent: ::Haml::Parser::ParseNode,
              old_children: T::Array[::Haml::Parser::ParseNode]
            ).returns(T::Array[::Haml::Parser::ParseNode])
          end
          def transform_children(parent, old_children)
            new_children = []

            old_children
              .reject { _1.type == :haml_comment }
              .chunk(&:type)
              .each do |type, children|
                if type == :plain
                  text = children.map { _1.value[:text].strip }.join(" ")
                  new_children.push(
                    ::Haml::Parser::ParseNode.new(
                      :plain,
                      children.first&.line || 1,
                      { text: },
                      parent,
                      []
                    )
                  )
                  next
                end

                children.each do |child|
                  if child.value[ADD_SPACE_LEFT]
                    new_children.push(
                      ::Haml::Parser::ParseNode.new(
                        :plain,
                        child.line,
                        { text: " " },
                        parent,
                        []
                      )
                    )
                  end

                  new_children.push(child)

                  if child.value[ADD_SPACE_RIGHT]
                    new_children.push(
                      ::Haml::Parser::ParseNode.new(
                        :plain,
                        child.line,
                        { text: " " },
                        parent,
                        []
                      )
                    )
                  end
                end
              end

            new_children
          end

          sig { params(ast: SyntaxTree::Node).returns(String) }
          def format_ruby_ast(ast)
            formatter = SyntaxTree::Formatter.new("", [], 80)
            ast.format(formatter)
            formatter.flush
            formatter.output.join.chomp
          end

          sig do
            params(
              value: String,
              block: T.proc.params(arg0: SyntaxTree::Node).void
            ).void
          end
          def visit_dynamic_attribute(value, &block)
            ast = SyntaxTree.parse(value)
            hash_parser_visitor = HashParserVisitor.new
            hash_parser_visitor.visit(ast)

            if klass = hash_parser_visitor.klass
              yield klass
            end

            unless hash_parser_visitor.length.zero?
              @out << ",\n"
              @out << indentation
              @out << "**#{format_ruby_ast(ast)}"
            end
          rescue => e
            # TODO: Print a helpful error message
            raise
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_plain(node)
            indent do
              @out << indentation
              case node.value
              in text: " "
                @out << '" "'
              in text:
                @out << "#{node.value[:text].strip.inspect}"
              end
            end
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_script(node)
            text = node.value[:text].strip

            if match = text.match(/\Areturn\s+(if|unless)\s+(.+)/)
              @out << "#{match[1]} #{match[2]}\n"
              indent do
                @out << indentation << "return("
                indent do
                  @out << indentation << "begin"
                  node.children.each_with_index do |child, i|
                    @out << "\n"
                    visit(child)
                  end
                  @out << "\n" << indentation << "end"
                end
                @out << "\n" << indentation << ")"
              end
              @out << "\n" << indentation << "end"
              return
            end

            next_sibling =
              node.parent.children[node.parent.children.index(node).succ]
            next_continues =
              next_sibling && next_sibling.type == :script &&
                next_sibling.value[:keyword] == "else"

            is_assignment = text.chomp.match?(/=\z/)
            emit_end = !(is_assignment || next_continues)

            @out << text

            unless node.children.empty?
              @out << " begin" if text == "return"

              indent do
                node.children.each_with_index do |child, i|
                  @out << "\n"
                  visit(child)
                end
              end

              @out << "\n"
              @out << indentation << "end" if emit_end
            end
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_silent_script(node)
            @out << "begin\n"
            indent do
              visit_script(node)
              @out << "\n" << indentation << "nil"
            end
            @out << "\n" << indentation << "end"
          end

          sig { params(method: Symbol, node: ::Haml::Parser::ParseNode).void }
          def method_missing(method, node)
            Console.logger.error("#{self.class.name}##{__method__}", <<~EOF)
            Please implement the following method:

            sig { params(node: ::#{node.class.name}).void }
            def #{method}(node)
            end
            EOF
          end
        end
      end
    end
  end
end
