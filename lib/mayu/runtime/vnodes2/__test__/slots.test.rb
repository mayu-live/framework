#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes2::SlotsTest < Minitest::Test
  include Mayu::Runtime::VNodes2::TestHelpers

  class SlotProbe < Mayu::Component::Base
    def render
      H[:div, H[:slot]]
    end
  end

  def test_slot_updates_children
    initial = H[:body, H[SlotProbe, H[:p, "before"]]]
    updated = H[:body, H[SlotProbe, H[:p, "after"]]]

    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new
    document.update(patcher, updated)

    set_text =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
      end

    refute_nil(set_text)
    assert_equal("after", set_text.content)
  end
end
