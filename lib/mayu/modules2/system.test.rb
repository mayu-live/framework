# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "system"

class TestSystem < Minitest::Test
  def test_system
    system = Mayu::Modules2::System.new(File.join(__dir__, "__test__"))

    x = system.load("foo.rb")
  end
end
