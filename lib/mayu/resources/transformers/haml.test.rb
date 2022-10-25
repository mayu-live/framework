# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "haml"

class TestHaml < Minitest::Test
  def test_transform
    source_path = "app/pages/Intro.haml"
    app_root = File.expand_path(File.join(__dir__, "..", "..", "example"))
    source_path = "app/components/MyComponent"

    result = Mayu::Resources::Transformers::Haml.to_ruby(<<~HAML)
    :ruby
      puts "hello"
      lol = "lolsan"

    %div.foo(class="bar" asdd=lol){class: "baz"}
      = "hello"
    HAML

    puts result

    assert(result == <<~RUBY)
    RUBY
  end

  def test_transform2
    root =
      File.expand_path(File.join(__dir__, "..", "..", "..", "..", "example"))

    transformed = transform_file(root:, path: "app/pages/Intro.haml")
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
