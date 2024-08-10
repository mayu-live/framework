# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    module Loaders
      StaticFile =
        Data.define do
          include SyntaxTree::DSL

          def call(loading_file)
            loading_file.with_digest.transform do
              SyntaxTree::Formatter.format("", build_code(_1))
            end
          end

          private

          def build_code(loading_file)
            hash = Base64.urlsafe_encode64(loading_file.digest)[0..10]
            filename =
              format("%s?%s", loading_file.path.delete_prefix("/"), hash)
            asset_path = File.join("/.mayu/assets", filename)

            Statements(
              [
                Assign(
                  VarField(Const("Default")),
                  StringLiteral([TStringContent(asset_path)], '"')
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
                                Const("Assets")
                              ),
                              Const("Generators")
                            ),
                            Const("WriteFile")
                          ),
                          Args(
                            [
                              StringLiteral([TStringContent(filename)], '"'),
                              StringLiteral(
                                [TStringContent(loading_file.absolute_path)],
                                '"'
                              )
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
