# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "syntax_tree"
require_relative "mutation_visitor"
require_relative "xml_utils"

module Mayu
  module Modules
    module Loaders
      module Transformers
        class Ruby
          class Formatter < SyntaxTree::Formatter
            def format(node, stackable: true)
              stack << node if stackable
              doc = nil

              # If there are comments, then we're going to format them around the node
              # so that they get printed properly.
              if node.comments.any?
                trailing = []
                last_leading = nil

                # First, we're going to print all of the comments that were found before
                # the node. We'll also gather up any trailing comments that we find.
                node.comments.each do |comment|
                  if comment.trailing?
                    trailing << comment
                  else
                    comment.format(self)
                    breakable(force: true)
                    last_leading = comment
                  end
                end

                # If the node has a stree-ignore comment right before it, then we're
                # going to just print out the node as it was seen in the source.
                doc =
                  if last_leading&.ignore?
                    range = source[node.start_char...node.end_char]
                    first = true

                    range.each_line(chomp: true) do |line|
                      if first
                        first = false
                      else
                        breakable_return
                      end

                      text(line)
                    end

                    breakable_return if range.end_with?("\n")
                  else
                    node.format(self)
                  end

                # Print all comments that were found after the node.
                trailing.each do |comment|
                  line_suffix(priority: COMMENT_PRIORITY) do
                    comment.inline? ? text(" ") : breakable
                    comment.format(self)
                    break_parent
                  end
                end
              else
                doc = node.format(self)
              end

              stack.pop if stackable
              doc
            end
          end

          class FrozenStringLiteralsVisitor < SyntaxTree::Visitor
            def visit_program(node)
              node.copy(statements: visit(node.statements))
            end

            def visit_statements(node)
              node.copy(
                body: [
                  SyntaxTree::Comment.new(
                    value: "# frozen_string_literal: true",
                    inline: false,
                    location: node.location
                  ),
                  *node.body
                ]
              )
            end
          end

          include SyntaxTree::DSL

          COLLECTIONS = {
            SyntaxTree::IVar => "state",
            SyntaxTree::GVar => "props"
          }

          def self.transform(source, path, using: [], component_base_class:)
            transformer = new
            # puts "\e[33m#{source}\e[0m"
            SyntaxTree.parse(component_base_class).statements.body => [
              component_base_path
            ]

            using =
              using.map do
                SyntaxTree.parse(_1).statements.body => [mod]
                mod
              end

            SyntaxTree
              .parse(source)
              .accept(transformer.heredoc_html)
              .then do
                transformer.wrap_in_class(
                  _1,
                  path,
                  component_base_path:,
                  using:
                )
              end
              .accept(transformer.frozen_strings)
              .then { Formatter.format(source, _1) }
          rescue SyntaxTree::Parser::ParseError => e
            puts "\e[1;31mError parsing: #{path}\e[0m"
            line = source.lines.to_a[e.lineno.pred].dup
            line[e.column, 0] = "\e[3m"
            puts "#{e.lineno}: #{line}\e[0m"
            raise
          end

          def frozen_strings = FrozenStringLiteralsVisitor.new

          def wrap_in_class(program, path, component_base_path:, using:)
            class_name =
              File.basename(path, ".*").sub(/\A[[:lower:]]/) { _1.upcase }

            statements =
              Statements(
                [
                  ClassDeclaration(
                    VarRef(Const(class_name)),
                    component_base_path,
                    BodyStmt(
                      Statements(
                        [
                          DefNode(
                            VarRef(Kw("self")),
                            Period("."),
                            Ident("module_path"),
                            nil,
                            BodyStmt(
                              Statements([VarRef(Kw("__FILE__"))]),
                              nil,
                              nil,
                              nil,
                              nil
                            )
                          ),
                          using_statements(using),
                          program.statements.body
                        ].compact.flatten
                      ),
                      nil,
                      nil,
                      nil,
                      nil
                    )
                  ),
                  unless class_name == "Default"
                    Assign(VarRef(Const("Default")), VarRef(Const(class_name)))
                  end,
                  MethodAddBlock(
                    CallNode(
                      ConstPathRef(VarRef(Const("Default")), Const("Styles")),
                      Period("."),
                      Ident("each"),
                      nil
                    ),
                    BlockNode(
                      BlockVar(Params([], [], [], [], [], [], nil), nil),
                      nil,
                      Statements(
                        [
                          CallNode(
                            nil,
                            nil,
                            Ident("add_asset"),
                            ArgParen(
                              Args(
                                [
                                  CallNode(
                                    ConstPathRef(
                                      VarRef(Const("Assets")),
                                      Const("Asset")
                                    ),
                                    Period("."),
                                    Ident("build"),
                                    ArgParen(
                                      Args(
                                        [
                                          CallNode(
                                            VarRef(Ident("_1")),
                                            Period("."),
                                            Ident("filename"),
                                            nil
                                          ),
                                          CallNode(
                                            VarRef(Ident("_1")),
                                            Period("."),
                                            Ident("content"),
                                            nil
                                          )
                                        ]
                                      )
                                    )
                                  )
                                ]
                              )
                            )
                          )
                        ]
                      )
                    )
                  )
                ]
              )
            program.copy(statements:)
          end

          def using_statements(using)
            using.map { Command(Ident("using"), Args([_1]), nil) }
          end

          def heredoc_html
            MutationVisitor.new.tap do |visitor|
              visitor.mutate(
                "XStringLiteral | Heredoc[beginning: HeredocBeg[value: '<<~HTML']]"
              ) do |node|
                tokenizer = XMLUtils::Tokenizer.new

                node.parts.flat_map do |child|
                  case child
                  in SyntaxTree::TStringContent
                    tokenizer.tokenize(child.value)
                  in SyntaxTree::StringEmbExpr
                    tokenizer.T(:statements, child.statements.accept(visitor))
                  end
                end

                parser = XMLUtils::Parser.new
                parser.parse(tokenizer.tokens.dup)

                statements =
                  parser.tokens.map { xml_token_to_ast_node(_1) }.compact

                Formatter.format("", Statements(statements))

                Statements(statements)
              end
            end
          end

          def xml_token_to_ast_node(token)
            case token
            in { type: :tag, value: { name:, attrs:, children: } }
              args = [
                SymbolLiteral(Ident(name.to_sym)),
                *children.map { xml_token_to_ast_node(_1) },
                unless attrs.empty?
                  BareAssocHash(attrs.map { xml_token_to_ast_node(_1) })
                end
              ].compact

              ARef(VarRef(Const("H")), Args(args))
            in { type: :attr, value: { name:, value: } }
              Assoc(
                StringLiteral([TStringContent(name)], '"'),
                xml_token_to_ast_node(value)
              )
            in { type: :attr_value, value: }
              StringLiteral([TStringContent(value)], '"')
            in { type: :var_ref, value: /\A@(.*)/ }
              ARef(call_self("state"), Args([SymbolLiteral(Ident($~[1]))]))
            in { type: :var_ref, value: /\A\$(.*)/ }
              ARef(
                VarRef(IVar("@__props")),
                Args([SymbolLiteral(Ident($~[1]))])
              )
            in type: :newline
              nil
            in { type: :string, value: }
              StringLiteral([TStringContent(value)], '"')
            in { type: :statements, value: }
              case value.body
              in []
                nil
              in [first]
                first
              in [*many]
                Begin(BodyStmt(value))
              end
            end
          end

          private

          def call_html(parts)
            call_self(:html, ArgParen(Args([StringLiteral(parts, '"')])))
          end

          def call_self(method, args = nil)
            CallNode(VarRef(Kw("self")), Period("."), Ident(method), args)
          end

          def update(nodes)
            MethodAddBlock(
              call_self("update"),
              BlockNode(Kw("{"), nil, Statements(Array(nodes)))
            )
          end

          def aref(node)
            ARef(
              call_self(COLLECTIONS.fetch(node.class)),
              Args([SymbolLiteral(Ident(strip_var_prefix(node.value)))])
            )
          end

          def aref_field(node)
            ARefField(
              call_self(COLLECTIONS.fetch(node.class)),
              Args([SymbolLiteral(Ident(strip_var_prefix(node.value)))])
            )
          end

          def strip_var_prefix(str)
            str.delete_prefix("@").delete_prefix("$")
          end
        end
      end
    end
  end
end
