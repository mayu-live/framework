#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require_relative "inline_style"

class Mayu::Runtime::InlineStyleTest < Minitest::Test
  def test_stringify_discards_nil_and_false_values
    assert_equal(
      "opacity:0;z-index:2;",
      Mayu::Runtime::InlineStyle.stringify(
        color_scheme: nil,
        display: false,
        opacity: 0,
        z_index: 2
      )
    )
  end
end
