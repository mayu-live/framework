require_relative "transformers/css"

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
                .format("", build_code(_1)).+("\n")
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
                .gsub(%r{/}, "__")
                .gsub(/([[:lower:]])([[:upper:]])/) { $~.captures.join("__") }

            custom_element_name =
              format(
                "%s__%s",
                basename,
                Base64.urlsafe_encode64(loading_file.digest, padding: false)[
                  0..10
                ]
              ).downcase

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
                          ConstPathRef(VarRef(Const("Assets")), Const("Asset")),
                          Period("."),
                          Ident("build"),
                          ArgParen(
                            Args(
                              [
                                StringLiteral([TStringContent(custom_element_name + ".js")], '"'),
                                CallNode(
                                  VarRef(Const("Base64")),
                                  Period("."),
                                  Ident("decode64"),
                                  ArgParen(
                                    StringLiteral([TStringContent(Base64.encode64(loading_file.source).strip)], '"')
                                  )
                                )
                              ]
                            )
                          )
                        )
                      ]
                    )
                  )
                ),
                Assign(
                  VarField(Const("Default")),
                  ARef(
                    ConstPathRef(
                      VarRef(Const("Mayu")),
                      Const("CustomElement")
                    ),
                    Args([
                      Args([SymbolLiteral(Ident(custom_element_name))]),
                      StringLiteral([TStringContent(custom_element_name + ".js")], '"')
                    ])
                  )
                )
              ]
            )
          end
        end
    end
  end
end
