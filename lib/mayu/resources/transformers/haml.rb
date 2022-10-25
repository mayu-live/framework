# typed: strict
# frozen_string_literal: true

require "bundler/setup"
require "syntax_tree"
require "syntax_tree/haml"
require "haml"

module Mayu
  module Resources
    module Transformers
      module Haml
        extend T::Sig

        sig { params(source: String).returns(String) }
        def self.to_ruby(source)
          ast = SyntaxTree::Haml.parse(source)
          out = StringIO.new
          Transformer.new(out).visit(ast)
          out.tap(&:rewind).read.to_s
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
                  return false unless child.respond_to?(:key)

                  case child.key
                  when SyntaxTree::StringLiteral
                    key = child.key.parts.first.value

                    if key == "class"
                      set_klass(child.value)
                      true
                    else
                      # TODO: Is there a better way to transform the tree?
                      # This is supposed to convert string keys into symbols
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
                    false
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

          sig { params(out: StringIO).void }
          def initialize(out)
            @out = out
            @level = T.let(0, Integer)
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

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_root(node)
            visit(node.children.shift) if node.children[0].type == :filter

            @out << indentation << "def render\n"

            node.children.each do |child|
              indent { visit(child) }
              @out << indentation
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
            case node.value[:name]
            when "ruby"
              @out << indentation << "# ruby:\n"
              @out << node.value[:text].gsub(/^/, indentation)
            when "css"
              @out << indentation << "# css:\n"
              @out << node.value[:text].gsub(/^/, indentation + "# ") + "\n"
            else
              @out << indentation << "# #{node.value[:name]}:\n"
              @out << node.value[:text].gsub(/^/, indentation + "# ")
            end
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_tag(node)
            name = node.value.fetch(:name)

            @out << indentation
            @out << "#{CREATE_ELEMENT_FN}("

            if name[0].downcase == name[0]
              @out << name.to_sym.inspect
            else
              @out << name
            end

            old_pos = @out.pos

            if value = node.value[:value]
              @out << ", (#{value})" unless value.empty?
            end

            indent do
              node
                .children
                .reject { _1.type == :haml_comment }
                .each do |child|
                  @out << ",\n"
                  visit(child)
                end
            end

            # TODO: Figure out a clever way to merge class names..
            # They can be passed in like this:
            #
            # %div.foo(class=bar){class: props[:class]}
            #
            # It should somehow figure out how to combine all fo these classes
            # in a convenient way...

            classes =
              T.let([], T::Array[T.any(String, Symbol, SyntaxTree::Node)])

            indent do
              node.value[:attributes].each do |attr, value|
                if attr == "class"
                  classes.push(*value.split.map(&:to_sym))
                  next
                end

                @out << ",\n"
                @out << indentation

                @out << "#{attr}: #{value.inspect}"
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
            end
            @out << "\n" << indentation unless @out.pos == old_pos

            @out << ")"
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
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_plain(node)
            @out << indentation << node.value[:text].inspect
          end

          sig { params(node: ::Haml::Parser::ParseNode).void }
          def visit_script(node)
            if node.children.empty?
              @out << indentation
              @out << "(#{node.value[:text].strip})"
            else
              @out << indentation
              @out << "(#{node.value[:text].strip}\n"
              node.children.each_with_index do |child, i|
                @out << ",\n" unless i.zero?
                indent { visit(child) }
              end
              @out << "\n"
              @out << indentation
              @out << "end)"
            end
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
