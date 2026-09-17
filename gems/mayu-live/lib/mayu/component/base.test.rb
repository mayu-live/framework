#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require_relative "base"

class Mayu::Component::BaseTest < Minitest::Test
  class AnonymousPathComponent < Mayu::Component::Base
  end

  class AbsolutePathComponent < Mayu::Component::Base
    def self.module_path = File.join(Dir.pwd, "app/pages/+page.haml")
  end

  class RelativePathComponent < Mayu::Component::Base
    def self.module_path = "app/pages/+page.haml"
  end

  def test_class_name_falls_back_when_module_path_is_missing
    assert_equal(AnonymousPathComponent.name, AnonymousPathComponent.to_s)
  end

  def test_module_path_is_shown_relative_to_the_working_directory
    assert_equal("app/pages/+page.haml", AbsolutePathComponent.to_s)
    assert_equal("app/pages/+page.haml", RelativePathComponent.to_s)
  end

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
