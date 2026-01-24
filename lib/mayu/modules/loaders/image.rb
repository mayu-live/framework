# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "image_size"
require "syntax_tree"

require_relative "../../image"
require_relative "transformers/frozen_string_literal_visitor"

module Mayu
  module Modules
    module Loaders
      Image =
        Data.define(:sizes) do
          include SyntaxTree::DSL

          def call(loading_file)
            loading_file.with_digest.transform do
              image_size = ImageSize.path(_1.absolute_path)

              SyntaxTree::Formatter.format(
                "",
                build_code(
                  _1.absolute_path,
                  image_size,
                  Base64.urlsafe_encode64(_1.digest)[0..10]
                )
              )
              # .tap { |source| puts source }
            end
          end

          private

          def build_code(absolute_path, image_size, digest)
            Statements(
              [
                Assign(
                  VarField(Const("Default")),
                  ARef(
                    ConstPathRef(VarRef(Const("Mayu")), Const("Image")),
                    Args(
                      [
                        BareAssocHash(
                          [
                            Assoc(
                              Label("versions:"),
                              build_versions(absolute_path, image_size, digest)
                            ),
                            Assoc(
                              Label("width:"),
                              Int((image_size.width || 1).to_s)
                            ),
                            Assoc(
                              Label("height:"),
                              Int((image_size.height || 1).to_s)
                            ),
                            Assoc(
                              Label("blur_src:"),
                              StringLiteral(
                                [
                                  TStringContent(
                                    build_blur_image_src(absolute_path)
                                  )
                                ],
                                '"'
                              )
                            )
                          ]
                        )
                      ]
                    )
                  )
                ),
                build_assets(absolute_path)
              ]
            ).accept(Transformers::FrozenStringLiteralVisitor.new)
          end

          def build_blur_image_src(absolute_path)
            Ractor
              .new(absolute_path) do |absolute_path|
                format = "webp"

                Magick::Image.read(absolute_path) => [image]

                image.resize_to_fit!(16)

                blob =
                  image.to_blob do |options|
                    options.quality = 80
                    options.format = format
                  end

                image.destroy!

                "data:image/#{format};base64,#{Base64.strict_encode64(blob)}"
              end
              .join
              .value
          end

          def build_versions(absolute_path, image_size, hash)
            widths = sizes.select { _1 < image_size.width }.sort.reverse
            basename = File.basename(absolute_path, ".*")
            format = "webp"

            ArrayLiteral(
              LBracket("["),
              Args(
                [image_size.width, *widths].uniq.map do |width|
                  filename =
                    format("%s-%dw.%s?%s", basename, width, format, hash)
                  ARef(
                    VarRef(Const("ImageVersion")),
                    Args(
                      [
                        StringLiteral([TStringContent(filename)], '"'),
                        Int(width.to_s)
                      ]
                    )
                  )
                end
              )
            )
          end

          def build_assets(absolute_path)
            MethodAddBlock(
              CallNode(
                CallNode(
                  VarRef(Const("Default")),
                  Period("."),
                  Ident("versions"),
                  nil
                ),
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
                            ARef(
                              ConstPathRef(
                                ConstPathRef(
                                  ConstPathRef(
                                    VarRef(Const("Mayu")),
                                    Const("Assets")
                                  ),
                                  Const("Generators")
                                ),
                                Const("Image")
                              ),
                              Args(
                                [
                                  CallNode(
                                    VarRef(Ident("_1")),
                                    Period("."),
                                    Ident("filename"),
                                    nil
                                  ),
                                  StringLiteral(
                                    [TStringContent(absolute_path)],
                                    '"'
                                  ),
                                  CallNode(
                                    VarRef(Ident("_1")),
                                    Period("."),
                                    Ident("width"),
                                    nil
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
              )
            )
          end
        end
    end
  end
end
