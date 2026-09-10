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

  class CallbackValidationProbe < Mayu::Component::Base
    class << self
      attr_accessor :instance
    end

    def initialize
      self.class.instance = self
      @invalid = false
    end

    def make_callback_invalid
      @invalid = true
      rerender!
    end

    def handle_click
    end

    def render
      callback =
        if @invalid
          H.callback(self, :missing_callback)
        else
          H.callback(self, :handle_click)
        end
      H[:button, "Callback", onclick: callback]
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

  def test_invalid_callback_created_during_an_update_emits_a_render_error
    descriptor = H[:body, H[CallbackValidationProbe]]

    run_engine(descriptor) do |engine|
      wait_until do
        CallbackValidationProbe.instance.instance_variable_get(:@__vnode_task)
      end

      CallbackValidationProbe.instance.make_callback_invalid

      commands =
        dequeue_until(engine) do |batch|
          batch.any? { it.is_a?(Mayu::Runtime::Commands::RenderError) }
        end
      error = commands.find { it.is_a?(Mayu::Runtime::Commands::RenderError) }

      assert_includes(error.message, "Callback method :missing_callback")
      assert_equal(CallbackValidationProbe.name, error.file)
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

  def test_created_subtree_emits_listeners_after_create_tree
    initial = H[:body]
    updated = H[:body, H[CallbackProbe]]
    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    collector = Mayu::Runtime::VNodes::CommandCollector.new

    engine.root.update(collector, updated)

    create_index =
      collector.commands.index do |command|
        command.is_a?(Mayu::Runtime::Commands::CreateTree)
      end
    listener_index =
      collector.commands.index do |command|
        command.is_a?(Mayu::Runtime::Commands::SetListener)
      end
    listener = collector.commands.fetch(listener_index)

    refute_nil(create_index)
    assert_operator(listener_index, :>, create_index)
    assert_equal("click", listener.name)
    assert_equal(1, engine.root.instance_variable_get(:@listeners).size)
  end

  def test_created_subtree_emits_all_nested_listeners
    component = CallbackProbe.new
    initial = H[:body]
    updated =
      H[
        :body,
        H[
          :section,
          H[:button, "First", onclick: H.callback(component, :handle_click)],
          H[:form, onsubmit: H.callback(component, :handle_click)]
        ]
      ]
    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    collector = Mayu::Runtime::VNodes::CommandCollector.new

    engine.root.update(collector, updated)

    listeners =
      collector.commands.select do |command|
        command.is_a?(Mayu::Runtime::Commands::SetListener)
      end

    assert_equal(%w[click submit], listeners.map(&:name))
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
