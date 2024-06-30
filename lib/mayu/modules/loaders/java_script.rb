# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "transformers/css"
require_relative "../../custom_element"

module Mayu
  module Modules
    module Loaders
      JavaScript =
        Data.define do
          include SyntaxTree::DSL

          def call(loading_file)
            # TODO: Use swc or something to support TypeScript and minification.

            loading_file.maybe_load_source.with_digest.transform do
              SyntaxTree::Formatter
                .format("", build_code(_1))
                .+("\n")
                .tap { |x| puts "\e[93m#{x}\e[0m" }
            end
          end

          private

          def build_code(loading_file)
            basename =
              loading_file
                .path
                .then { File.join(File.dirname(_1), File.basename(_1, ".*")) }
                .sub(%r{\A\./}, "")
                .sub(%r{\A/}, "")
                .gsub(%r{/}, "-")
                .gsub(/([[:lower:]])([[:upper:]])/) { $~.captures.join("--") }

            custom_element_name =
              format(
                "%s--%s",
                basename,
                Base64.urlsafe_encode64(loading_file.digest, padding: false)[
                  0..10
                ]
              ).downcase.sub(/_+$/, "").tr("_", "-")

            filename = "#{custom_element_name}.js"

            Statements(
              [
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
                            Const("Text")
                          ),
                          Args(
                            [
                              StringLiteral([TStringContent(filename)], '"'),
                              CallNode(
                                VarRef(Const("Base64")),
                                Period("."),
                                Ident("decode64"),
                                ArgParen(
                                  StringLiteral(
                                    [
                                      TStringContent(
                                        Base64.encode64(
                                          loading_file.source
                                        ).strip
                                      )
                                    ],
                                    '"'
                                  )
                                )
                              )
                            ]
                          )
                        )
                      ]
                    )
                  )
                ),
                Assign(
                  VarField(Const("Default")),
                  ARef(
                    ConstPathRef(VarRef(Const("Mayu")), Const("CustomElement")),
                    Args(
                      [
                        Args(
                          [
                            DynaSymbol(
                              [TStringContent(custom_element_name)],
                              '"'
                            )
                          ]
                        ),
                        StringLiteral([TStringContent(filename)], '"')
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
