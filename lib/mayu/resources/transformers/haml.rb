# typed: strict
# frozen_string_literal: true

require "bundler/setup"
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

        class Transformer < SyntaxTree::Haml::Visitor
          extend T::Sig

          CREATE_ELEMENT_FN = T.let("Mayu::VDOM::H.h2", String)

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

            if value = node.value[:value]
              @out << ", (#{value})" unless value.empty?
            end

            node
              .children
              .reject { _1.type == :haml_comment }
              .each do |child|
                @out << ",\n"
                indent { visit(child) }
              end

            node.value[:attributes].each do |attr, value|
              @out << ",\n"

              indent do
                @out << indentation

                if attr == "class"
                  @out << "class: styles[#{value.split.map(&:to_sym).map(&:inspect).join(", ")}]"
                else
                  @out << "#{attr}: #{value.inspect}"
                end
              end
            end

            if dynamics = node.value[:dynamic_attributes].old
              unless dynamics.empty?
                @out << ",\n"

                indent { @out << indentation << "**#{dynamics}" }
              end
            end

            @out << ")"
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
