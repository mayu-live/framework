#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::CallbacksTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

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

  class InvalidCallbackProbe < Mayu::Component::Base
    def handle_click(_first, _second)
    end

    def render
      H[:button, onclick: H.callback(self, :handle_click)]
    end
  end

  class CallbackErrorProbe < Mayu::Component::Base
    def handle_click
      raise "callback failed"
    end

    def render
      H[:button, "Fail", onclick: H.callback(self, :handle_click)]
    end
  end

  def test_initial_html_contains_no_callback_wiring
    engine =
      Mayu::Runtime::Engine.new(
        H[:body, H[CallbackProbe]],
        metrics: NullMetrics.new
      )

    html = engine.render
    refute_includes(html, "Mayu.callback")
    refute_includes(html, "data-mayu-on")

    listener = engine.listener_commands.first
    assert_instance_of(Mayu::Runtime::Commands::SetListener, listener)
    assert_equal("click", listener.name)
  end

  def test_raw_string_event_handlers_are_rejected
    error =
      assert_raises(ArgumentError) do
        Mayu::Runtime::Engine.new(
          H[:body, H[:button, onclick: "alert('no')"]],
          metrics: NullMetrics.new
        )
      end

    assert_includes(error.message, "Raw string event handler")
  end

  def test_invalid_callback_signatures_are_rejected
    error =
      assert_raises(ArgumentError) do
        Mayu::Runtime::Engine.new(
          H[:body, H[InvalidCallbackProbe]],
          metrics: NullMetrics.new
        )
      end

    assert_includes(error.message, "must accept no arguments")
  end

  def test_event_callback_attribute
    component = CallbackProbe.new
    initial = H[:body, H[:button, "Click"]]
    updated =
      H[
        :body,
        H[:button, "Click", onclick: H.callback(component, :handle_click)]
      ]

    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root

    collector = Mayu::Runtime::VNodes::CommandCollector.new
    document.update(collector, updated)

    set_listener =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::SetListener) &&
          patch.name == "click"
      end

    refute_nil(set_listener)
    assert_match(/\A[A-Za-z0-9]+\z/, set_listener.listener_id)
  end

  def test_event_listener_unregistered_on_change
    component = CallbackProbe.new
    initial =
      H[
        :body,
        H[:button, "Click", onclick: H.callback(component, :handle_click)]
      ]
    updated = H[:body, H[:button, "Click", onclick: nil]]

    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root

    collector = Mayu::Runtime::VNodes::CommandCollector.new
    document.update(collector, initial)

    listeners = document.instance_variable_get(:@listeners)
    assert_equal(1, listeners.size)

    collector = Mayu::Runtime::VNodes::CommandCollector.new
    document.update(collector, updated)

    remove_listener =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::RemoveListener) &&
          patch.name == "click"
      end

    refute_nil(remove_listener)
    assert_equal(0, listeners.size)
  end

  def test_engine_callback_emits_patches
    initial = H[:body, H[CallbackProbe]]

    run_engine(initial) do |engine|
      document = engine.root

      collector = Mayu::Runtime::VNodes::CommandCollector.new
      document.update(collector, initial)

      component = find_component(document, CallbackProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until do
        document.instance_variable_get(:@listeners).any? &&
          instance.singleton_methods.include?(:rerender!)
      end

      listener = document.instance_variable_get(:@listeners).values.first
      refute_nil(listener)

      engine.callback(listener.id, {})

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

      set_text =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("Click 1", set_text.content)
    end
  end

  def test_callback_error_overlay_can_be_disabled
    engine =
      Mayu::Runtime::Engine.new(
        H[:body, H[CallbackErrorProbe]],
        metrics: NullMetrics.new,
        render_exceptions: false
      )

    run_engine_instance(engine) do
      listener = engine.root.instance_variable_get(:@listeners).values.first
      completion = engine.callback(listener.id, {})
      Async::Task.current.with_timeout(0.5) { completion.dequeue }

      assert_no_patches(engine)
    end
  end
end
