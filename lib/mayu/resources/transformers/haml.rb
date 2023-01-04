# typed: true
# frozen_string_literal: true

require "ripper"
require "syntax_suggest"
require "syntax_suggest/code_line"
require "syntax_suggest/explain_syntax"
require "syntax_suggest/lex_all"
require "syntax_suggest/ripper_errors"
require "syntax_tree"
require "syntax_tree/haml"
require_relative "css"

module Mayu
  module Resources
    module Transformers
      module Haml
        class MutationVisitor < SyntaxTree::Visitor::MutationVisitor
          # This class visits more nodes than the parent class.
          # This should probably be fixed in the syntax_tree gem,
          # but I don't know what other nodes need to be fixed.

          def self.build(&block)
            new.tap { yield _1 }
          end

          def visit_assign(node)
            node.copy(target: visit(node.target), value: visit(node.value))
          end

          def visit_assoc_splat(node)
            node.copy(value: visit(node.value))
          end

          def visit_assoc(node)
            node.copy(key: visit(node.key), value: visit(node.value))
          end

          def visit_aref(node)
            node.copy(
              collection: visit(node.collection),
              index: visit(node.index)
            )
          end

          def visit_opassign(node)
            node.copy(target: visit(node.target), value: visit(node.value))
          end

          def visit_binary(node)
            node.copy(left: visit(node.left), right: visit(node.right))
          end

          def visit_if_op(node)
            node.copy(
              predicate: visit(node.predicate),
              truthy: visit(node.truthy),
              falsy: visit(node.falsy)
            )
          end
        end

        class TransformResult < T::Struct
          const :filename, String
          const :output, String
          const :content_hash, String
          const :css, T.nilable(CSS::TransformResult)
          const :source_map, T::Hash[String, T.untyped]
        end

        class TransformOptions < T::Struct
          const :source, String
          const :source_path, String
          const :source_line, Integer

          # TODO: Remove content_hash, it does not seem to be used?
          const :content_hash, T.nilable(String)

          const :transform_elements_to_classes, T::Boolean, default: true
          const :enable_new_helper_ident, T::Boolean, default: false

          def source_path_without_extension
            File.join(
              File.dirname(source_path),
              File.basename(source_path, ".*")
            ).delete_prefix("./")
          end
        end

        extend T::Sig

        sig { params(options: TransformOptions).returns(TransformResult) }
        def self.transform(options)
          result =
            SyntaxTree::Haml.parse(options.source).accept(
              Transformer.new(options)
            )

          TransformResult.new(
            filename: options.source_path,
            output: result.source,
            content_hash: Digest::SHA256.digest(result.source),
            css: result.styles.first,
            source_map: {
            }
          )
        end

        class RubyBuilder
          include SyntaxTree::DSL

          def initialize(options)
            @options = options
          end

          def assign_const(name, value) = Assign(VarField(Const(name)), value)
          def self_var_ref = VarRef(Kw("self"))

          def create_program(setup, styles, render)
            Program(
              Statements(
                [
                  Comment("# frozen_string_literal: true", false),
                  assign_const("Self", setup_component(styles)),
                  *setup,
                  create_render(render)
                ]
              )
            ).accept(StateAndPropsTransformer.new.visitor)
          end

          def const_path(*names)
            names.reduce(nil) do |parent, name|
              const = Const(name)

              if T.cast(parent, T.untyped)
                ConstPathRef(parent, const)
              else
                TopConstRef(const)
              end
            end
          end

          def setup_component(styles)
            CallNode(
              nil,
              nil,
              Ident("setup_component"),
              ArgParen(
                Args(
                  [
                    BareAssocHash(
                      assocs(
                        assets:
                          array(styles.map { string_literal(_1.filename) }),
                        styles: props_hash(CSS.merge_classnames(styles))
                      )
                    )
                  ]
                )
              )
            )
          end

          def assocs(**kwargs)
            kwargs.map { |key, value| Assoc(Label("#{key}:"), value) }
          end

          def array(elems)
            ArrayLiteral(LBracket("["), Args(elems))
          end

          def create_render(statements)
            Command(
              Ident("public"),
              Args(
                [
                  DefNode(
                    nil,
                    nil,
                    Ident("render"),
                    nil,
                    BodyStmt(
                      Statements(
                        [
                          # set_fiber_local("current_component", VarRef(Kw("self"))),
                          *statements
                        ]
                      ),
                      nil,
                      nil,
                      nil,
                      nil
                    )
                  )
                ]
              ),
              nil
            )
          end

          def set_fiber_local(ident, value)
            Assign(
              ARefField(
                VarRef(Const("Fiber")),
                Args([SymbolLiteral(Ident(ident))])
              ),
              value
            )
          end

          def slot(name = nil, fallback: nil)
            if fallback in [_, *]
              return(
                MethodAddBlock(
                  slot(name, fallback: nil),
                  BlockNode(
                    Kw("do"),
                    nil,
                    BodyStmt(Statements(Array(fallback)), nil, nil, nil, nil)
                  )
                )
              )
            end

            # call_helpers(:slot, [Ident("children"), name].compact)
            call_helpers(:slot, [name].compact)
          end

          def tag(name, children, attrs_to_merge)
            ARef(
              ConstPathRef(
                ConstPathRef(VarRef(Const("Mayu")), Const("VDOM")),
                Const("H")
              ),
              Args(
                [
                  tag_name_or_class(name),
                  *children,
                  merge_props(attrs_to_merge)
                ].flatten.compact
              )
            )
          end

          def tag_name_or_class(name)
            case name
            in /\A[A-Z]/
              Ident(name)
            else
              SymbolLiteral(Ident(name))
            end
          end

          def splat_hash(node)
            BareAssocHash([AssocSplat(node)])
          end

          def merge_props(attrs_to_merge)
            return if attrs_to_merge.empty?

            splat_hash(call_helpers(:merge_props, attrs_to_merge))
          end

          def first_or_array(nodes)
            case nodes
            in [node]
              node
            else
              ArrayLiteral(LBracket("["), Args(nodes))
            end
          end

          def sym(str)
            if str.match(/\A[\w_]+\z/)
              SymbolLiteral(Ident(str))
            else
              DynaSymbol([TStringContent(str)], '"')
            end
          end

          def props_hash(attrs)
            HashLiteral(
              LBrace("{"),
              attrs.map do |key, value|
                if key.to_s == "class" && value in String
                  Assoc(
                    SymbolLiteral(Ident(key.to_s)),
                    first_or_array(value.split.map { sym(_1) })
                  )
                else
                  Assoc(
                    sym(key.to_s),
                    case value
                    in Symbol
                      SymbolLiteral(Ident(value.to_s))
                    in String
                      StringLiteral([TStringContent(value.to_s)], :'"')
                    in SyntaxTree::ArrayLiteral
                      value
                    in TrueClass | FalseClass | NilClass
                      VarRef(Kw(value.to_s))
                    end
                  )
                end
              end
            )
          end

          def try_split_string_literal(node)
            case node
            in SyntaxTree::StringLiteral
              split_string_literal(node)
            in [SyntaxTree::StringLiteral => node]
              split_string_literal(node)
            else
              node
            end
          end

          def split_string_literal(string_literal)
            string_literal
            # string_literal
            #   .parts
            #   .map do |part|
            #     case part
            #     in SyntaxTree::TStringContent
            #       string_literal(part.value)
            #     in SyntaxTree::StringEmbExpr
            #       part.statements
            #     end
            #   end
            #   .flatten
          end

          def ruby_script(statements)
            case statements
            in []
              nil
            in [SyntaxTree::StringLiteral => string_literal]
              split_string_literal(string_literal)
            in [statement]
              statement
            else
              Begin(BodyStmt(Statements(statements), nil, nil, nil, nil))
            end
          end

          def silent(node)
            case node
            in SyntaxTree::ReturnNode
              node
            else
              Begin(
                BodyStmt(
                  Statements([node, VarRef(Kw("nil"))]),
                  nil,
                  nil,
                  nil,
                  nil
                )
              )
            end
          end

          def compute(node)
            # MethodAddBlock(
            #   call_helpers(:compute),
            #   BlockNode(
            #     Kw("do"),
            #     nil,
            #     BodyStmt(Statements([node]), nil, nil, nil, nil)
            #   )
            # )
            node
          end

          def mayu_const_path
            ConstPathRef(VarRef(Const("Mayu")), Const("VDOM"))
            # Const("Mayu")
          end

          def call_helpers(method, *args)
            CallNode(
              Ident("mayu"),
              Period("."),
              Ident(method.to_s),
              wrap_args(args.flatten.compact)
            )
          end

          def helper_ident
            if @options.enable_new_helper_ident
              CallNode(VarRef(Kw("self")), Period("."), Ident("Mayu"), nil)
            else
              Ident("mayu")
            end
          end

          def wrap_args(args)
            args.empty? ? nil : ArgParen(Args(args))
          end

          def string_literal(value) =
            StringLiteral([TStringContent(value.to_s)], '"')
          def call_freeze(node) =
            CallNode(node, Period("."), Ident("freeze"), nil)
        end

        class ParseError < StandardError
        end

        class Transformer < SyntaxTree::Haml::Visitor
          class Result < T::Struct
            const :program, SyntaxTree::Program
            const :styles, T::Array[CSS::TransformResult]

            def source
              SyntaxTree::Formatter.format("", program)
            end
          end

          def initialize(options)
            @options = options
            @builder = RubyBuilder.new(options)
            @state = {}
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
              in type: :tag
                render.push(child)
              end
            end

            Result.new(
              program:
                @builder.create_program(
                  group_control_statements(setup),
                  styles,
                  group_control_statements(render)
                ),
              styles:
            )
          end

          def visit_haml_comment(node)
            nil
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

            if @options.transform_elements_to_classes
              attrs.push(@builder.props_hash(class: :"__#{name}"))
            end

            attrs.push(@builder.props_hash(attributes)) unless attributes.empty?

            if old = dynamic_attributes.old
              attrs.push(*parse_ruby(old))
            end

            if new = dynamic_attributes.new
              attrs.push(
                *parse_ruby(new)
                  .map { _1.accept(string_keys_to_labels_mutation_visitor) }
                  .map { _1.accept(wrap_handler_mutation_visitor) }
              )
            end

            if object_ref = node.value[:object_ref]
              unless object_ref == :nil
                parse_ruby(object_ref) => [key]
                attrs.push(@builder.props_hash(key:))
              end
            end

            @builder.tag(
              name,
              if value
                if node.value[:parse]
                  parse_ruby(value, fix: false) => statements
                  @builder.ruby_script(statements)
                elsif !value.empty?
                  @builder.string_literal(value.to_s)
                end
              else
                visit_tag_children(node.children)
              end,
              attrs
            )
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
                  @builder.compute(group_condition(:if, chunk))
                in [{ type: :script, value: { keyword: "case" } }, *]
                  @builder.compute(group_condition(:case, chunk))
                in [{ type: :script, value: { keyword: "begin" } }, *]
                  @builder.compute(group_condition(:begin, chunk))
                else
                  chunk.map { _1.accept(self) }
                end
              end
              .flatten
              .compact
          end

          def group_condition(type, chunk)
            parse_ruby(join_ruby_script_nodes(chunk), fix: true) => [statement]

            visitor = SyntaxTree::Visitor::MutationVisitor.new

            chunk.shift if type == :case

            visitor.mutate("Statements") do |node|
              top = chunk.shift

              if node.child_nodes in [SyntaxTree::VoidStmt]
                @builder.Statements(visit_tag_children(top.children))
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
            nodes.map { _1.value[:text] }.join("\n")
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
              @builder.ruby_script(parse_ruby(text)) if text
            in { name: "css", text: }
              CSS.transform(
                source: text,
                source_path:
                  @options.source_path_without_extension + ".haml (inline css)",
                source_line: node.line,
                content_hash: Digest::SHA256.hexdigest(text)[0..7].to_s
              )
            in { name: "plain", text: }
              case text.inspect.each_line.to_a
              in []
                # noop
              in [line]
                @builder.string_literal(text)
              in [*lines]
                @builder.Heredoc(lines.map { @builder.TStringContent(_1) })
              end
            end
          end

          def visit_plain(node)
            node.value => { text: }
            @builder.string_literal(CGI.escape_html(text))
          end

          def visit_script(node)
            case node.value[:text].strip
            when /\Areturn\s+(?<type>if|unless)\s+(?<condition_source>.+)/
              $~ => { type:, condition_source: }

              parse_ruby(condition_source, fix: true) => [condition]

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
              @builder.compute(transform_script_node(node))
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

            visitor = SyntaxTree::Visitor::MutationVisitor.new

            visitor.mutate("Statements[body: [VoidStmt]]") do
              @builder.Statements(visit_tag_children(node.children))
            end

            @builder.ruby_script([statement.accept(visitor)])
          end

          def parse_ruby(source, fix: false)
            source = fix_syntax_by_adding_missing_pairs(source) if fix

            SyntaxTree.parse(source).statements.body
          rescue SyntaxTree::Parser::ParseError => e
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
            SyntaxSuggest::LexAll.new(source:).each { left_right.count_lex(_1) }
            left_right.missing
            [source, *left_right.missing].join("\n")
          end

          def wrap_handler_mutation_visitor
            visitor = SyntaxTree::Visitor::MutationVisitor.new

            visitor.mutate(
              "Assoc[key: Label, value: VCall[value: Ident]]"
            ) do |assoc|
              if assoc.key.value.start_with?("on")
                handler_name = @builder.SymbolLiteral(assoc.value.value)

                @builder.Assoc(
                  assoc.key,
                  @builder.call_helpers(:handler, [handler_name])
                )
              else
                assoc
              end
            end

            visitor
          end

          def string_keys_to_labels_mutation_visitor
            visitor = SyntaxTree::Visitor::MutationVisitor.new

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

        class StateAndPropsTransformer
          include SyntaxTree::DSL

          COLLECTIONS = {
            SyntaxTree::IVar => "state",
            SyntaxTree::GVar => "props"
          }

          def visitor
            MutationVisitor.build do |visitor|
              visitor.mutate(
                "VarRef[value: GVar[value: /\\A\\$\\w+/]]"
              ) { |var_ref| aref(var_ref.value) }

              visitor.mutate(
                "Assign[target: VarField[value: GVar]]"
              ) do |assign|
                assign => { target: { target: { value: var_name } } }
                loc = assign.target.location
                raise "Can not write to prop #{var_name} on line #{loc.start_line} col #{loc.start_column}"
              end

              visitor.mutate("VarRef[value: IVar]") do |var_ref|
                aref(var_ref.value)
              end

              # visitor.mutate(
              #   "OpAssign[target: VarField[value: IVar]]"
              # ) do |assign|
              #   assign.copy(target: aref_field(assign.target.value))
              # end
              #
              # visitor.mutate(
              #   "Assign[target: VarField[value: IVar]]"
              # ) do |assign|
              #   assign.copy(target: aref_field(assign.target.value))
              # end
            end
          end

          private

          def aref(node)
            ARef(
              call_self(COLLECTIONS.fetch(node.class)),
              Args([var_to_symbol(node)])
            )
          end

          def aref_field(node)
            ARefField(
              call_self(COLLECTIONS.fetch(node.class)),
              Args([var_to_symbol(node)])
            )
          end

          def call_self(method)
            CallNode(VarRef(Kw("self")), Period("."), Ident(method), nil)
          end

          def var_to_symbol(node)
            SymbolLiteral(Ident(strip_var_prefix(node.value)))
          end

          def strip_var_prefix(str)
            str[/\A[@$]?(.*)/, 1]
          end
        end
        class HashKeyExtractorVisitor
          extend T::Sig

          sig do
            params(node: SyntaxTree::HashLiteral).returns(
              T::Hash[T.untyped, T.untyped]
            )
          end
          def visit_hash(node)
            hash = {}

            node.assocs.each do |child|
              if extract_key(child.key) in key
                hash[key] = extract_value(child.value)
              end
            end

            hash
          end

          sig do
            params(node: SyntaxTree::Node).returns(
              T.nilable(T.any(String, Symbol))
            )
          end
          def extract_key(node)
            case node
            when SyntaxTree::StringLiteral
              node.parts => [{ value: }]
              value
            when SyntaxTree::Label
              node.value
            end
          end

          sig { params(node: SyntaxTree::Node).returns(T.untyped) }
          def extract_value(node)
            node
          end
        end
      end
    end
  end
end
