#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require_relative "base"

class Mayu::Component::BaseTest < Minitest::Test
  class KlenodComponent < Mayu::Component::Base
    class ClassNames
      def self.class_name(values)
        values
          .flatten
          .filter_map do |value|
            case value
            when Symbol
              { title: "scoped-title" }.fetch(value)
            when Hash
              value.filter_map { |name, enabled| "scoped-#{name}" if enabled }
            else
              value
            end
          end
          .join(" ")
      end
    end
  end

  class LegacyComponent < Mayu::Component::Base
    Styles = Object.new
    Styles.define_singleton_method(:[]) { |*classes| classes.map(&:to_s) }
  end

  def test_merge_props_uses_klenod_class_names_when_available
    assert_equal(
      { class: "scoped-title scoped-active", data_id: "example" },
      KlenodComponent.merge_props(
        { class: [:title, { active: true }], "data-id": "example" }
      )
    )
  end

  def test_merge_props_keeps_legacy_style_sheets_for_legacy_components
    assert_equal(
      { class: %w[title active] },
      LegacyComponent.merge_props({ class: %i[title active] })
    )
  end
end
