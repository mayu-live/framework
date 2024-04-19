# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# Released under AGPL-3.0

require "base64"
require "digest/sha2"
require "mayu/css"
require "syntax_tree"
require_relative "../../../style_sheet"

module Mayu
  module Modules
    module Loaders
      module Transformers
        class CSS
          include SyntaxTree::DSL

          def self.transform(source_path, source)
            Mayu::CSS
              .transform(source_path, source)
              .then do
                new(source_path, _1).build_inline_ast(assign_default: true)
              end
              .then { SyntaxTree::Formatter.format("", _1).rstrip + "\n" }
          end

          def self.transform_inline(source_path, source, **options)
            Mayu::CSS
              .transform(source_path, source)
              .then { new(source_path, _1, **options).build_inline_ast }
          end

          def initialize(
            source_path,
            parse_result,
            dependency_const_prefix: "Dep_",
            code_const_name: "CODE",
            content_hash_const_name: "CONTENT_HASH"
          )
            @source_path = source_path
            @parse_result = parse_result
            @dependency_const_prefix = dependency_const_prefix
            @code_const_name = code_const_name
            @content_hash_const_name = content_hash_const_name
          end

          def build_inline_ast(assign_default: false)
            new_style_sheet =
              ARef(
                ConstPathRef(VarRef(Const("Mayu")), Const("StyleSheet")),
                Args(
                  [
                    BareAssocHash(
                      [
                        Assoc(
                          Label("source_filename:"),
                          StringLiteral([TStringContent(@source_path)], '"')
                        ),
                        Assoc(
                          Label("content_hash:"),
                          build_content_hash_string
                        ),
                        Assoc(Label("classes:"), build_classes_hash),
                        Assoc(Label("content:"), build_code_heredoc)
                      ]
                    )
                  ]
                )
              )

            Statements(
              [
                *build_imports,
                if assign_default
                  Assign(VarField(Const("Default")), VarRef(new_style_sheet))
                else
                  new_style_sheet
                end
              ]
            )
          end

          private

          def build_imports
            @parse_result.dependencies.map do |dep|
              dep => { placeholder:, url: }

              Assign(
                VarField(Const(@dependency_const_prefix + placeholder)),
                build_import(url)
              )
            end
          end

          def build_import(url)
            Command(
              Ident("import"),
              Args([StringLiteral([TStringContent(url)], '"')]),
              nil
            )
          end

          def build_content_hash_string
            StringLiteral(
              [
                TStringContent(
                  @parse_result
                    .code
                    .then { Digest::SHA256.digest(_1) }
                    .then { Base64.urlsafe_encode64(_1, padding: false) }
                )
              ],
              '"'
            )
          end

          def build_classes_hash
            HashLiteral(LBrace("{"), build_classes_assocs)
          end

          def build_classes_assocs
            {
              **@parse_result.classes,
              **@parse_result.elements.transform_keys { "__#{_1}" }
            }.transform_keys(&:to_s)
              .sort_by(&:first)
              .map do |key, value|
                Assoc(
                  if key.match(/\A[A-Za-z0-9_]\z/)
                    Label("#{key}:")
                  else
                    DynaSymbol([TStringContent(key)], '"')
                  end,
                  StringLiteral([TStringContent(value.to_s)], '"')
                )
              end
          end

          def build_code_heredoc
            Heredoc(
              HeredocBeg("<<CSS"),
              HeredocEnd("CSS"),
              nil,
              build_code_heredoc_inner
            )
          end

          def build_code_heredoc_inner
            parts = []
            remains = @parse_result.code.gsub("\\", "\\\\\\\\") + "\n"

            @parse_result.dependencies.map do |dep|
              dep => { placeholder: }
              remains.split(placeholder, 2) => [part, remains]

              parts.push(
                TStringContent(part),
                StringEmbExpr(
                  Statements(
                    [
                      CallNode(
                        ConstPathRef(
                          VarRef(Const("Mayu")),
                          Const("StyleSheet")
                        ),
                        Period("."),
                        Ident("encode_url"),
                        ArgParen(
                          Args(
                            [
                              CallNode(
                                VarRef(
                                  Const(@dependency_const_prefix + placeholder)
                                ),
                                Period("."),
                                Ident("public_path"),
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
            end

            parts.push(TStringContent(remains)) unless remains.empty?

            parts
          end
        end
      end
    end
  end
end
