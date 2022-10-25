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
    source_path = "app/pages/demos/tree/page.css"
    app_root = File.expand_path(File.join(__dir__, "..", "..", "example"))
    source = File.read(File.join(app_root, source_path))
    result = Mayu::CSS.transform(source:, source_path:, app_root:)

    puts source
    puts result.output
  end
end
