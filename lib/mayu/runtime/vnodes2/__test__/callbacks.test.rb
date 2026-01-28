#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes2::CallbacksTest < Minitest::Test
  include Mayu::Runtime::VNodes2::TestHelpers

  class CallbackProbe < Mayu::Component::Base
    def initialize
      @count = 0
    end

    def render
      H[:button, "Click #{@count}", onclick: H.callback(self, :handle_click)]
    end

    def handle_click
      @count += 1
      rerender!
    end
  end

  def test_event_callback_attribute
    component = CallbackProbe.new
    initial = H[:body, H[:button, "Click"]]
    updated =
      H[
        :body,
        H[:button, "Click", onclick: H.callback(component, :handle_click)]
      ]

    engine = Mayu::Runtime::VNodes2::Engine.new(initial)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new
    document.update(patcher, updated)

    set_attribute =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::SetAttribute) &&
          patch.name == :onclick
      end

    refute_nil(set_attribute)
    assert_match(
      /\AMayu\.callback\(event,'[A-Za-z0-9]+'\)\z/,
      set_attribute.value
    )
  end

  def test_event_listener_unregistered_on_change
    component = CallbackProbe.new
    initial =
      H[
        :body,
        H[:button, "Click", onclick: H.callback(component, :handle_click)]
      ]
    updated = H[:body, H[:button, "Click", onclick: nil]]

    engine = Mayu::Runtime::VNodes2::Engine.new(initial)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new
    document.update(patcher, initial)

    listeners = document.instance_variable_get(:@listeners)
    assert_equal(1, listeners.size)

    patcher = Mayu::Runtime::VNodes2::Patcher.new
    document.update(patcher, updated)

    remove_attribute =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::RemoveAttribute) &&
          patch.name == :onclick
      end

    refute_nil(remove_attribute)
    assert_equal(0, listeners.size)
  end

  def test_engine_callback_emits_patches
    initial = H[:body, H[CallbackProbe]]

    run_engine(initial) do |engine|
      document = engine.root

      patcher = Mayu::Runtime::VNodes2::Patcher.new
      document.update(patcher, initial)

      component = find_component(document, CallbackProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until do
        document.instance_variable_get(:@listeners).any? &&
          instance.singleton_methods.include?(:rerender!)
      end

      listener = document.instance_variable_get(:@listeners).values.first
      refute_nil(listener)

      engine.callback(listener.id, {})

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      set_text =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("Click 1", set_text.content)
    end
  end
end
