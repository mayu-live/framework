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

            def visit_tag_children(children)
              children
                .reject { _1 in { type: :plain, value: { text: "" } } }
                .then { join_plain_nodes(_1) }
                .then { prepend_whitespace(_1) }
                .then { append_whitespace(_1) }
                .then { group_control_statements(_1) }
                .flatten
            end

            def join_plain_nodes(children)
              children
                .chunk_while do |prev, curr|
                  (
                    (prev in { type: :plain, value: { text: prev_text } }) &&
                      (curr in { type: :plain, value: { text: new_text } })
                  )
                end
                .map do |chunk|
                  case chunk
                  in [{ type: :plain } => first, *]
                    text = chunk.map { _1.value[:text].to_s.strip }.join(" ")
                    first.value[:text] = text
                    first
                  else
                    chunk
                  end
                end
                .flatten
                .compact
            end

            IN_RE = /\A\s*in\s+/

            def group_control_statements(children)
              children
                .chunk_while do |a, b|
                  case [a, b]
                  in [
                       { type: :script, value: { keyword: "if" | "elsif" } },
                       { type: :script, value: { keyword: "elsif" | "else" } }
                     ]
                    true
                  in [
                       { type: :script, value: { keyword: "case" | "when" } },
                       { type: :script, value: { keyword: "when" | "else" } }
                     ]
                    true
                  in [
                       {
                         type: :script,
                         value: { keyword: "case" } | { text: IN_RE }
                       },
                       {
                         type: :script,
                         value: { keyword: "else" } | { text: IN_RE }
                       }
                     ]
                    true
                  in [
                       { type: :script, value: { keyword: "begin" } },
                       {
                         type: :script,
                         value: { keyword: "rescue" | "else" | "ensure" }
                       }
                     ]
                    true
                  in [
                       { type: :script, value: { keyword: "rescue" } },
                       { type: :script, value: { keyword: "else" | "ensure" } }
                     ]
                    true
                  in [
                       { type: :script, value: { keyword: "else" } },
                       { type: :script, value: { keyword: "ensure" } }
                     ]
                    true
                  else
                    false
                  end
                end
                .map do |chunk|
                  case chunk
                  in [{ type: :script, value: { keyword: "if" } }, *]
                    group_condition(:if, chunk)
                  in [{ type: :script, value: { keyword: "case" } }, *]
                    group_condition(:case, chunk)
                  in [{ type: :script, value: { keyword: "begin" } }, *]
                    group_condition(:begin, chunk)
                  else
                    chunk.map { |node| node.accept(self) }
                  end
                end
                .flatten
                .compact
            end

            def wrap_multiple_expressions_in_array(nodes)
              if nodes.length > 1
                [@builder.flattened_array(nodes)]
              else
                nodes
              end
            end

            def group_condition(type, chunk)
              chunk
                .then { join_ruby_script_nodes(_1) }
                .then { parse_ruby(_1, fix: true) } => [statement]

              visitor = MutationVisitor.new

              chunk.shift if type == :case

              visitor.mutate("Statements") do |node|
                top = chunk.shift

                if node.child_nodes in [SyntaxTree::VoidStmt]
                  @builder.Statements(
                    top
                      .children
                      .then { visit_tag_children(_1) }
                      .then { wrap_multiple_expressions_in_array(_1) }
                  )
                else
                  unless top.children.empty?
                    raise "Line #{top.line} should not have children."
                  end

                  node
                end
              end

              @builder.ruby_script([statement.accept(visitor)])
            end

            def join_ruby_script_nodes(nodes)
              nodes.map { |node| node.value[:text] }.join("\n")
            end

            def prepend_whitespace(children)
              [nil, *children].each_cons(2)
                .map do |prev, curr|
                  if prev in {
                       type: :tag, value: { nuke_outer_whitespace: true }
                     }
                    if curr in { type: :plain, value: { text: } }
                      curr.value = { text: " #{text}" }
                    else
                      next make_space(curr), curr
                    end
                  end

                  curr
                end
            end

            def append_whitespace(children)
              [*children, nil].each_cons(2)
                .flat_map do |curr, succ|
                  if succ in {
                       type: :tag, value: { nuke_inner_whitespace: true }
                     }
                    if curr in { type: :plain, value: { text: } }
                      curr.value = { text: "#{text} " }
                    else
                      next curr, make_space(curr)
                    end
                  end

                  curr
                end
            end

            def make_space(ref_node)
              ::Haml::Parser::ParseNode.new(
                :plain,
                ref_node.line,
                { text: " " },
                ref_node.parent,
                []
              )
            end

            def visit_filter(node)
              case node.value
              in { name: "ruby", text: }
                if text
                  @builder.wrap_in_begin_end(
                    @builder.ruby_script(
                      parse_ruby(text, mark_sourcemap: node.line)
                    )
                  )
                end
              in { name: "css", text: }
                text
              in { name: "plain", text: }
                case text.rstrip.lines.to_a
                in []
                  # noop
                in [line]
                  @builder.string_literal(line)
                in [*lines]
                  id =
                    RbNaCl::Hash
                      .sha256(Base64.encode64(@options.content_hash) + text)
                      .unpack("h*")
                      .join

                  @builder.Heredoc(
                    @builder.HeredocBeg("<<~PLAIN_#{id}"),
                    @builder.HeredocEnd("PLAIN_#{id}"),
                    true,
                    lines.map { @builder.TStringContent(_1.sub(/\n*$/, "\n")) }
                  )
                end
              end
            end

            def visit_plain(node)
              node.value => { text: }
              @builder.string_literal(text)
            end

            def source_map_mark(line, content, &)
              [
                Modules::SourceMap::Mark[line, content].to_comment,
                yield
              ].flatten
            end

            def visit_script(node)
              visit_script2(node).tap do
                _1.comments.replace(
                  [
                    Modules::SourceMap::Mark[
                      node.line,
                      node.value[:text].strip
                    ].to_comment
                  ]
                )
              end
            end

            def visit_script2(node)
              case node.value[:text].strip
              when /\Areturn\s+(?<type>if|unless)\s+(?<condition_source>.+)/
                $~ => { type:, condition_source: }

                parse_ruby(
                  condition_source,
                  fix: true,
                  mark_sourcemap: node.line
                ) => [condition]

                statements =
                  @builder.Statements(
                    [
                      @builder.ReturnNode(
                        @builder.Args(visit_tag_children(node.children))
                      )
                    ]
                  )

                case type
                in "if"
                  @builder.IfNode(condition, statements, nil)
                in "unless"
                  @builder.UnlessNode(condition, statements, nil)
                end
              when /\Areturn/
                @builder.ReturnNode(
                  @builder.Args(visit_tag_children(node.children))
                )
              else
                transform_script_node(node)
              end
            end

            def with_state(name, value, &block)
              @state[name], prev = value, @state[name]
              yield prev
            ensure
              @state[name] = prev
            end

            def visit_silent_script(node)
              with_state(:is_silent, true) do |was_silent|
                if was_silent
                  visit_script(node)
                else
                  @builder.silent(visit_script(node))
                end
              end
            end

            def transform_script_node(node)
              source = node.value.fetch(:text).strip

              if node.children.empty?
                parse_ruby(source, fix: false) => statements
                return @builder.ruby_script(statements)
              end

              parse_ruby(source, fix: true) => [statement]

              visitor = MutationVisitor.new

              visitor.mutate("Statements[body: [VoidStmt]]") do
                @builder.Statements(visit_tag_children(node.children))
              end

              @builder.ruby_script([statement.accept(visitor)])
            end

            def parse_ruby(source, fix: false, mark_sourcemap: false)
              source = fix_syntax_by_adding_missing_pairs(source) if fix

              statements =
                SyntaxTree
                  .parse(source)
                  .statements
                  .accept(
                    StateAndPropsTransformer.new(@provides_context).visitor
                  )

              if mark_sourcemap
                statements
                  .accept(TransformSingleExpressionMethodsVisitor.new.visitor)
                  .accept(SourceMapMarkRubyVisitor.new(source, mark_sourcemap))
                  .body
              else
                statements.body
              end
            rescue SyntaxTree::Parser::ParseError
              explain =
                SyntaxSuggest::ExplainSyntax.new(
                  code_lines: SyntaxSuggest::CodeLine.from_source(source)
                ).call

              msg = ["Failed parsing Ruby: #{source}"]

              msg.push <<~MSG unless explain.errors.empty?
                  Errors:
                    #{explain.errors.join("  \n")}
                MSG

              msg.push <<~MSG unless explain.missing.empty?
                  Missing:
                    #{explain.missing.map { explain.why(_1) }.join("  \n")}
                MSG

              raise ParseError, "\n#{msg.join("\n")}"
            end

            def fix_syntax_by_adding_missing_pairs(source)
              left_right = SyntaxSuggest::LeftRightLexCount.new
              SyntaxSuggest::LexAll
                .new(source:)
                .each { left_right.count_lex(_1) }
              left_right.missing
              [source, *left_right.missing].join("\n")
            end

            def wrap_handler_mutation_visitor
              visitor = MutationVisitor.new

              visitor.mutate(
                "Assoc[key: Label, value: VCall[value: Ident]]"
              ) do |assoc|
                if assoc.key.value.start_with?("on")
                  @builder.Assoc(
                    assoc.key,
                    @builder.create_callback(assoc.value.value)
                  )
                else
                  assoc
                end
              end

              visitor
            end

            def string_keys_to_labels_mutation_visitor
              visitor = MutationVisitor.new

              visitor.mutate("Assoc[key: StringLiteral]") do |assoc|
                @builder.Assoc(
                  @builder.Label(
                    assoc.key.parts.map(&:value).join.gsub("-", "_") + ":"
                  ),
                  assoc.value
                )
              end

              visitor
            end
          end
        end
      end
    end
  end
end
