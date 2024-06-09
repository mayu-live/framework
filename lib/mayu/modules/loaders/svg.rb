# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../../svg"

module Mayu
  module Modules
    module Loaders
      SVG =
        Data.define do
          include SyntaxTree::DSL

          def call(loading_file)
            loading_file.maybe_load_source.with_digest.transform do
              SyntaxTree::Formatter.format(
                "",
                build_code(_1.path, _1.source, _1.digest)
              )
            end
          end

          private

          def build_code(path, source, digest)
            filename =
              format(
                "%s.%s.svg",
                File.basename(path, ".*"),
                Base64.urlsafe_encode64(digest)[0..10]
              )

            width = 1
            height = 1

            Statements(
              [
                Assign(
                  VarField(Const("Default")),
                  ARef(
                    ConstPathRef(VarRef(Const("Mayu")), Const("SVG")),
                    Args(
                      [
                        BareAssocHash(
                          [
                            Assoc(
                              Label("filename:"),
                              StringLiteral([TStringContent(filename)], '"')
                            ),
                            Assoc(Label("width:"), Int(width.to_s)),
                            Assoc(Label("height:"), Int(height.to_s))
                          ]
                        )
                      ]
                    )
                  )
                ),
                CallNode(
                  nil,
                  nil,
                  Ident("add_asset"),
                  ArgParen(
                    Args(
                      [
                        ARef(
                          ConstPathRef(
                            ConstPathRef(
                              ConstPathRef(
                                VarRef(Const("Mayu")),
                                Const("Modules")
                              ),
                              Const("Generators")
                            ),
                            Const("Text")
                          ),
                          Args(
                            [
                              StringLiteral([TStringContent(filename)], '"'),
                              StringLiteral([TStringContent(source)], '"')
                            ]
                          )
                        )
                      ]
                    )
                  )
                )
              ]
            )
          end
        end
    end
  end
end
