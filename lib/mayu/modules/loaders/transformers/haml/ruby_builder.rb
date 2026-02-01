# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../css"
require_relative "../../../../style_sheet"

module Mayu
  module Modules
    module Loaders
      module Transformers
        module Haml
          class RubyBuilder
            include SyntaxTree::DSL

            def initialize(options)
              @options = options
            end

            def assign_const(name, value) = Assign(VarField(Const(name)), value)
            def self_var_ref = VarRef(Kw("self"))

            def create_program(provides_context, setup, styles, render)
              Program(
                Statements(
                  [
                    assign_const("Self", VarRef(Kw("self"))),
                    # assign_const("FILENAME", VarRef(Kw("__FILE__"))),
                    # assign_const(
                    #   "PROVIDES_CONTEXT",
                    #   CallNode(
                    #     QSymbols(
                    #       QSymbolsBeg("i"),
                    #       provides_context.map { TStringContent(_1) }
                    #     ),
                    #     Period("."),
                    #     Ident("freeze"),
                    #     nil
                    #   )
                    # ),
                    *assign_styles(styles),
                    *setup,
                    create_render(render)
                  ].select { !!_1 }
                )
              )
            end

            def assign_styles(styles)
              [
                assign_const(
                  "INLINE_STYLES",
                  ArrayLiteral(
                    LBracket("["),
                    Args(
                      [
                        unless styles.empty?
                          Begin(
                            BodyStmt(
                              CSS.transform_inline(
                                @options.source_path_without_extension +
                                  ".haml.css",
                                styles.join("\n"),
                                dependency_const_prefix: "CSS_Dep_"
                              ),
                              nil,
                              nil,
                              nil,
                              nil
                            )
                          )
                        end
                      ].compact
                    )
                  )
                ),
                assign_const(
                  "Styles",
                  CallNode(
                    ConstPathRef(
                      ConstPathRef(VarRef(Const("Mayu")), Const("Component")),
                      Const("StyleSheets")
                    ),
                    Period("."),
                    Ident("new"),
                    ArgParen(
                      Args(
                        [
                          VarRef(Kw("self")),
                          CallNode(
                            ArrayLiteral(
                              LBracket("["),
                              Args(
                                [
                                  ArgStar(VarRef(Const("INLINE_STYLES"))),
                                  CallNode(
                                    nil,
                                    nil,
                                    Ident("import?"),
                                    ArgParen(
                                      Args(
                                        [
                                          StringLiteral(
                                            [
                                              TStringContent(
                                                File.join(
                                                  ".",
                                                  File.basename(
                                                    @options.source_path_without_extension
                                                  ) + ".css"
                                                )
                                              )
                                            ],
                                            '"'
                                          )
                                        ]
                                      )
                                    )
                                  )
                                ].compact
                              )
                            ),
                            Period("."),
                            Ident("compact"),
                            nil
                          )
                        ]
                      )
                    )
                  )
                )
              ]
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

            def wrap_in_begin_end(statements)
              if statements in SyntaxTree::Begin
                statements = statements.bodystmt.statements
              end

              Begin(
                BodyStmt(
                  Statements([*Array(statements), VarRef(Kw("nil"))]),
                  nil,
                  nil,
                  nil,
                  nil
                )
              )
            end

            # def assocs(**kwargs)
            #   kwargs.map { |key, value| Assoc(Label("#{key}:"), value) }
            # end
            #
            def array(elems)
              ArrayLiteral(LBracket("["), Args(elems))
            end

            def flattened_array(elems)
              CallNode(array(elems), Period("."), Ident("flatten"), nil)
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
                      BodyStmt(Statements(statements), nil, nil, nil, nil)
                    )
                  ]
                ),
                nil
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

              CallNode(
                factory,
                Period("."),
                Ident("slot"),
                wrap_args([Kw("self"), name].compact)
              )
            end

            def ruby_comment(content)
              Comment("# #{content}", false)
            end

            def comment(content)
              CallNode(
                factory,
                Period("."),
                Ident("comment"),
                ArgParen(Args([StringLiteral([TStringContent(content)], '"')]))
              )
            end

            def factory = @options.factory

            def tag(name, children, attrs_to_merge)
              ARef(
                factory,
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
                  if key.to_s == "class"
                    Assoc(
                      SymbolLiteral(Ident(key.to_s)),
                      first_or_array(value.to_s.split.map { sym(_1) })
                      # ARef(
                      #   VarRef(Const("Styles")),
                      #   Args(value.to_s.split.map { sym(_1) })
                      # )
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
                        VarRef(Kw(value.inspect))
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

            def mayu_const_path
              # ConstPathRef(VarRef(Const("Mayu")), Const("Mayu"))
              Const("Mayu")
            end

            def create_callback(name)
              CallNode(
                factory,
                Period("."),
                Ident("callback"),
                ArgParen(Args([VarRef(Kw("self")), SymbolLiteral(name)]))
              )
            end

            def call_helpers(method, *args)
              CallNode(
                CallNode(VarRef(Kw("self")), Period("."), Ident("class"), nil), # mayu_const_path,
                Period("."),
                Ident(method.to_s),
                wrap_args([*args.flatten.compact])
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
        end
      end
    end
  end
end
