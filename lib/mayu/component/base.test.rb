#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require_relative "base"

class Mayu::Component::BaseTest < Minitest::Test
  def test_exposes_vdom_children_as_klenod_slots
    children =
      Mayu::Runtime::Descriptors::Children[
        [
          Mayu::Runtime::H[:span, "Default"],
          Mayu::Runtime::H[:span, "Named", slot: :menu]
        ]
      ]
    component = Mayu::Component::Base.allocate
    component.instance_variable_set(:@__children, children)

    assert_equal children.slots, component.__slots
  end
end
