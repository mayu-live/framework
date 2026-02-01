# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "pry"
require "ripper"
require "securerandom"
require "syntax_suggest"
require "syntax_suggest/api"
require "syntax_suggest/code_line"
require "syntax_suggest/explain_syntax"
require "syntax_suggest/lex_all"
require "syntax_suggest/ripper_errors"
require "syntax_tree"
require "syntax_tree/haml"
require "rbnacl"
require_relative "mutation_visitor"
require_relative "haml/ruby_builder"
require_relative "haml/source_map_mark_ruby_visitor"
require_relative "haml/transform_single_expression_methods_visitor"
require_relative "haml/state_and_props_transformer"
require_relative "haml/hash_key_extractor"
require_relative "haml/transformer_helpers"
require_relative "../../source_map"

module Mayu
  module Modules
    module Loaders
      module Transformers
        module Haml
          TransformResult =
            Data.define(:filename, :output, :content_hash, :css, :source_map)

          TransformOptions =
            Data.define(
              :source,
              :source_path,
              :source_line,
              :content_hash,
              :factory,
              :transform_elements_to_classes,
              :enable_new_helper_ident
            ) do
              def source_path_without_extension
                File.join(
                  File.dirname(source_path),
                  File.basename(source_path, ".*")
                ).delete_prefix("./")
              end
            end

          def self.transform(source, relative_path, factory: "H")
            SyntaxTree.parse(factory).statements.body => [factory]

            options =
              TransformOptions[
                source:,
                source_path: relative_path,
                source_line: 1,
                content_hash: RbNaCl::Hash.sha256(source),
                factory:,
                transform_elements_to_classes: false,
                enable_new_helper_ident: false
              ]

            result =
              SyntaxTree::Haml.parse(source).accept(Transformer.new(options))

            TransformResult.new(
              filename: options.source_path,
              output: result.source,
              content_hash: Digest::SHA256.digest(result.source),
              css: result.styles.first,
              source_map: {
              }
            )
          end

          class ParseError < StandardError
          end

          class Transformer < SyntaxTree::Haml::Visitor
            include TransformerHelpers
            Result =
              Data.define(:program, :styles) do
                def source
                  SyntaxTree::Formatter.format("", program)
                end
              end

            def initialize(options)
              @options = options
              @builder = RubyBuilder.new(options)
              @state = {}
              @sourcemap = []
              @provides_context = Set.new
            end

            def visit_haml_comment(node)
            end

            def visit_root(node)
              setup = []
              styles = []
              render = []

              node.children.each do |child|
                case child
                in { type: :filter, value: { name: "ruby" } }
                  if setup.empty? && styles.empty?
                    setup.push(child)
                  else
                    render.push(child)
                  end
                in type: :script | :silent_script
                  render.push(child)
                in { type: :filter, value: { name: "css" } }
                  styles.push(child.accept(self))
                in { type: :filter, value: { name: "plain" } }
                  render.push(child)
                in type: :tag
                  render.push(child)
                else
                  render.push(child)
                end
              end

              setup = setup.map { _1.accept(self) }
              render =
                render
                  .then { group_control_statements(_1) }
                  .then { wrap_multiple_expressions_in_array(_1) }

              Result.new(
                program:
                  @builder.create_program(
                    @provides_context.to_a,
                    setup,
                    styles,
                    render
                  ),
                styles:
              )
            end

            def visit_comment(node)
              return node if node.is_a?(SyntaxTree::Comment)

              @builder.comment(
                if node.children
                  node
                    .children
                    .map do |child|
                      formatter =
                        SyntaxTree::Haml::Format::Formatter.new("", +"", 80)
                      child.format(formatter)
                      formatter.flush
                      formatter.output
                    end
                    .join("\n")
                else
                  @builder.comment(node.value[:text])
                end
              )
            end

            def visit_slot_tag(node)
              node.value => { attributes:, dynamic_attributes: }

              name = nil

              if new = dynamic_attributes.new
                parse_ruby(dynamic_attributes.new) => [parsed_attributes]
                hash = parsed_attributes.accept(HashKeyExtractorVisitor.new)

                name = hash[:name] || hash["name"]
              end

              if attr = attributes["name"]
                name ||= @builder.string_literal(attr)
              end

              return(
                @builder.slot(
                  name,
                  fallback: node.children.map { _1.accept(self) }
                )
              )
            end

            def visit_tag(node)
              node.value => {
                name:, attributes:, dynamic_attributes:, self_closing:, value:
              }

              return visit_slot_tag(node) if name == "slot"

              attrs = []

              attrs.push(@builder.props_hash(class: :"__#{name}"))

              unless attributes.empty?
                attrs.push(@builder.props_hash(attributes))
              end

              if old = dynamic_attributes.old
                attrs.push(
                  *source_map_mark(node.line, old.strip) { parse_ruby(old) }
                )
              end

              if new = dynamic_attributes.new
                attrs.push(
                  *source_map_mark(node.line, new.strip) do
                    parse_ruby(new)
                      .map { _1.accept(string_keys_to_labels_mutation_visitor) }
                      .map { _1.accept(wrap_handler_mutation_visitor) }
                  end
                )
              end

              if object_ref = node.value[:object_ref]
                unless object_ref == :nil
                  parse_ruby(object_ref) => [key]
                  attrs.push(@builder.props_hash(key:))
                end
              end

              children = [
                if value
                  if node.value[:parse]
                    parse_ruby(value, fix: false) => statements

                    source_map_mark(node.line, value.strip) do
                      @builder.ruby_script(statements)
                    end
                  elsif !value.empty?
                    @builder.string_literal(value.to_s)
                  end
                else
                  visit_tag_children(node.children)
                end
              ].flatten

              @builder.tag(name, children, attrs)
            end
          end
        end
      end
    end
  end
end
