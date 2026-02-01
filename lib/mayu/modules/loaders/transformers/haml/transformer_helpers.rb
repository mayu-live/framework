# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    module Loaders
      module Transformers
        module Haml
          module TransformerHelpers
            IN_RE = /\A\s*in\s+/

            def visit_tag_children(children)
              children
                .reject { it in { type: :plain, value: { text: "" } } }
                .then { join_plain_nodes(it) }
                .then { prepend_whitespace(it) }
                .then { append_whitespace(it) }
                .then { group_control_statements(it) }
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
                    text = chunk.map { it.value[:text].to_s.strip }.join(" ")
                    first.value[:text] = text
                    first
                  else
                    chunk
                  end
                end
                .flatten
                .compact
            end

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
                .then { join_ruby_script_nodes(it) }
                .then { parse_ruby(it, fix: true) } => [statement]

              visitor = MutationVisitor.new

              chunk.shift if type == :case

              visitor.mutate("Statements") do |node|
                top = chunk.shift

                if node.child_nodes in [SyntaxTree::VoidStmt]
                  @builder.Statements(
                    top
                      .children
                      .then { visit_tag_children(it) }
                      .then { wrap_multiple_expressions_in_array(it) }
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
                    lines.map { @builder.TStringContent(it.sub(/\n*$/, "\n")) }
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
                it.comments.replace(
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
                    #{explain.missing.map { explain.why(it) }.join("  \n")}
                MSG

              raise ParseError, "\n#{msg.join("\n")}"
            end

            def fix_syntax_by_adding_missing_pairs(source)
              left_right = SyntaxSuggest::LeftRightLexCount.new
              SyntaxSuggest::LexAll
                .new(source:)
                .each { left_right.count_lex(it) }
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
