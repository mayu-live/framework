require "image_size"
require "syntax_tree"

require_relative "../../image"

module Mayu
  module Modules
    module Loaders
      Image = Data.define do
        include SyntaxTree::DSL

        def call(loading_file)
          loading_file
            .with_digest
            .transform do
              image_size = ImageSize.path(_1.absolute_path)

              SyntaxTree::Formatter
                .format("", build_code(_1.path, image_size, _1.digest))
                .tap { |x| puts x }
            end
        end

        private

        def build_code(path, image_size, digest)
          Assign(
            VarField(Const("Default")),
            ARef(
              ConstPathRef(
                VarRef(Const("Mayu")),
                Const("Image")
              ),
              Args([
                BareAssocHash([
                  Assoc(
                    Label("path:"),
                    StringLiteral([TStringContent(path)], '"')
                  ),
                  Assoc(
                    Label("format:"),
                    SymbolLiteral(Ident(image_size.format.to_s))
                  ),
                  Assoc(
                    Label("digest:"),
                    StringLiteral([TStringContent(Base64.urlsafe_encode64(digest, padding: false))], '"')
                  ),
                  Assoc(
                    Label("size:"),
                    ArrayLiteral(
                      LBracket("["),
                      Args([
                        Int(image_size.width.to_s),
                        Int(image_size.height.to_s)
                      ])
                    )
                  ),
                ])
              ])
            )
          )
        end
      end
    end
  end
end
