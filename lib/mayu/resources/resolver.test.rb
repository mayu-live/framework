# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "./resolver"

class TestResolver < Minitest::Test
  def test_resolver
    system =
      Mayu::Resources::System.new(
        File.join(__dir__, "..", "..", "..", "example2")
      )
    resolver = Mayu::Resources::Resolver.new(system)

    p resolver.resolve("/pages/page")
    p resolver.resolve("/pages/pagex")
  end
end
