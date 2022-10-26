# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "haml"

class TestHaml < Minitest::Test
  # def test_transform
  #   source_path = "app/pages/Intro.haml"
  #   app_root = File.expand_path(File.join(__dir__, "..", "..", "example"))
  #   source_path = "app/components/MyComponent"
  #
  #   result = Mayu::Resources::Transformers::Haml.to_ruby(<<~HAML)
  #   :ruby
  #     puts "hello"
  #     lol = "lolsan"
  #     id = "check123"
  #     props = { label: "label", asd: "asd" }
  #
  #   %div.foo(class="bar" asdd=lol){class: "baz"}
  #     = "hello"
  #     %input(id=id){
  #       class: classname,
  #       type: "checkbox",
  #       placeholder: props[:label],
  #       **props.except(:label),
  #     }
  #   HAML
  #
  #   puts result
  # end

  def test_transform2
    root =
      File.expand_path(File.join(__dir__, "..", "..", "..", "..", "example"))

    transformed =
      transform_file(root:, path: "app/pages/demos/pokemon/:id/page.haml")
    puts "Transformed:"
    puts transformed
    puts "Formatted:"
    puts SyntaxTree.format(transformed)
  end

  private

  def transform_file(root:, path:)
    Mayu::Resources::Transformers::Haml.to_ruby(
      File.read(File.join(root, path))
    )
  end
end
