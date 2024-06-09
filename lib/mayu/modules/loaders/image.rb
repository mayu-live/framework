# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "image_size"
require "syntax_tree"

require_relative "../../image"

module Mayu
  module Modules
    module Loaders
      IMAGE_BREAKPOINTS = [
        120,
        240,
        320,
        640,
        768,
        960,
        1024,
        1366,
        1600,
        1920,
        3840
      ]

      Image =
        Data.define do
          include SyntaxTree::DSL

          def call(loading_file)
            loading_file.with_digest.transform do
              image_size = ImageSize.path(_1.absolute_path)

              SyntaxTree::Formatter.format(
                "",
                build_code(
                  _1.absolute_path,
                  image_size,
                  Base64.urlsafe_encode64(_1.digest)
                )
              )
              # .tap { |x| puts x }
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
                            )
                          ]
                        )
                      ]
                    )
                  )
                ),
                build_assets(absolute_path)
              ]
            )
          end

          def build_versions(absolute_path, image_size, digest)
            widths =
              IMAGE_BREAKPOINTS.select { _1 < image_size.width }.sort.reverse
            basename = File.basename(absolute_path, ".*")
            format = "webp"
            hash = Base64.urlsafe_encode64(digest)[0..10]

            ArrayLiteral(
              LBracket("["),
              Args(
                [image_size.width, *widths].uniq.map do |width|
                  filename =
                    format("%s-%dw.%s.%s", basename, width, hash, format)
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
                                    Const("Modules")
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
