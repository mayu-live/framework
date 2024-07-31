#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require_relative "style_sheets"

class Mayu::Component::StyleSheets::Test < Minitest::Test
  def test_classes
    style_sheets =
      Mayu::Component::StyleSheets.new(
        Object.new,
        [
          Mayu::StyleSheet[
            source_filename: "foo.css",
            content_hash: nil,
            content: nil,
            classes: {
              __li: "tag-li",
              __ul: "tag-ul",
              active: "active",
              item: "item",
              hello: "hello1"
            }
          ],
          Mayu::StyleSheet[
            source_filename: "foo.css",
            content_hash: nil,
            content: nil,
            classes: {
              hello: "hello2"
            }
          ]
        ]
      )

    assert_equal(%w[item], style_sheets[:item])
    assert_equal(%w[item], style_sheets[:item, active: false])
    assert_equal(%w[item active], style_sheets[:item, active: true])
    assert_equal(%w[hello1 hello2], style_sheets[:hello])
    assert_equal(%w[tag-li foobar], style_sheets[:__li, "foobar" => true])

    assert_output(nil, /Could not find classes:/) do
      style_sheets[:non_existant]
    end
  end
end
