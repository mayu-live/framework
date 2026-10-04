# frozen_string_literal: true

require "minitest/autorun"
require_relative "warning_filter"

class Mayu::WarningFilterTest < Minitest::Test
  def test_suppresses_only_the_io_buffer_experimental_warning
    _, error =
      capture_io do
        Warning.warn("warning: IO::Buffer is experimental and may change\n")
      end

    assert_empty(error)
  end

  def test_keeps_other_warnings
    message = "warning: another experimental feature\n"

    _, error = capture_io { Warning.warn(message) }

    assert_equal(message, error)
  end
end
