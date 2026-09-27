# frozen_string_literal: true

require "minitest/autorun"

require_relative "../build"

class Mayu::Build::DevelopmentProviderTest < Minitest::Test
  class FakeParseError < ::Klenod::Build::SourceError
    def kind = "Haml parse error"

    private

    def location(error)
      Location.new(line: 2, column: 4, detail: error.message, hints: ["Close the parenthesis"])
    end
  end

  def test_a_build_error_is_formatted_without_its_backtrace
    provider = Mayu::Build::DevelopmentProvider.allocate
    error =
      FakeParseError.new(
        SyntaxError.new("unexpected token"),
        source: "%p\n%p= )\n",
        module_id: "app:/broken.haml"
      )
    error.set_backtrace(["vendor/bundle/gems/klenod-build/lib/klenod/build/graph.rb:975"])

    report = provider.build_error_report(error)

    assert_includes(report, "app:/broken.haml")
    assert_includes(report, "unexpected token")
    assert_includes(report, "Close the parenthesis")
    refute_includes(report, "graph.rb")
    refute_includes(report, "\e[")
  end

  def test_other_errors_are_left_to_the_default_logger
    provider = Mayu::Build::DevelopmentProvider.allocate

    assert_nil(provider.build_error_report(RuntimeError.new("boom")))
  end
end
