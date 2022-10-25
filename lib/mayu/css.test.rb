# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "css"

class TestCSS < Minitest::Test
  # def test_transform
  #   source_path = "app/pages/Intro.css"
  #   app_root = File.expand_path(File.join(__dir__, "..", '..', 'example'))
  #   source_path = "app/components/MyComponent"
  #
  #   result = Mayu::CSS.transform(source: <<~CSS, source_path:, app_root:)
  #     .foo {
  #       background: #f0f;
  #     }
  #   CSS
  #
  #   assert(result.classes == {
  #     "foo" => "app/components/MyComponent.foo?317Lw9X"
  #   })
  # end

  def test_transform2
    source_path = "app/pages/Intro.css"
    source_path = "app/pages/demos/tree/page.css"

    root = File.expand_path(File.join(__dir__, "..", "..", "example"))

    puts transform_file(root:, path: "app/pages/demos/tree/page.css").output
    puts transform_file(root:, path: "app/pages/Intro.css").output
  end

  private

  def transform_file(root:, path:)
    Mayu::CSS.transform(
      source: File.read(File.join(root, path)),
      app_root: root,
      source_path: path
    )
  end
end
