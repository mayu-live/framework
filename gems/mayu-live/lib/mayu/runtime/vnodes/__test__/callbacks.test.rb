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

  class SlowHandlerProbe < Mayu::Component::Base
    class << self
      attr_accessor :gate, :received
    end

    def render
      H[
        :div,
        onmousemove: H.callback(self, :handle_event),
        onclick: H.callback(self, :handle_event)
      ]
    end

    def handle_event(event)
      self.class.received << event[:n]
      self.class.gate.dequeue
    end
  end

  # Renders between two state changes, like a handler waiting on a database.
  class SettleProbe < Mayu::Component::Base
    def initialize
      @step = 0
    end

    def render
      H[:button, "Step #{@step}", onclick: H.callback(self, :handle_click)]
    end

    def handle_click
      @step = 1
      rerender!
      Async::Task.current.sleep(0.05)
      @step = 2
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

    def handle_subscribe
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

  def test_missing_callback_names_the_haml_location_and_suggests_a_handler
    component = CallbackValidationProbe.new
    callback =
      Mayu::Runtime::Descriptors::Callback[
        component,
        :subscribe,
        ["app:/pages/newsletter.haml", 17]
      ]

    error =
      assert_raises(Mayu::Runtime::VNodes::VAttributes::NoCallbackMethodError) do
        Mayu::Runtime::VNodes::VAttributes::Listener[callback].validate!
      end

    assert_equal(["app:/pages/newsletter.haml:17:in 'render'"], error.backtrace)
    assert_includes(error.message, "Callback method :subscribe")
    assert_includes(error.message, "Did you mean?  handle_subscribe")
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
          H[:select, on_change: H.callback(component, :handle_click)],
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

    assert_equal(%w[click change submit], listeners.map(&:name))
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

  def test_equivalent_callback_preserves_the_listener
    component = CallbackProbe.new
    initial =
      H[
        :body,
        H[:button, "Click", onclick: H.callback(component, :handle_click)]
      ]
    updated =
      H[
        :body,
        H[:button, "Click", onclick: H.callback(component, :handle_click)]
      ]
    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root
    listener = document.instance_variable_get(:@listeners).values.fetch(0)
    collector = Mayu::Runtime::VNodes::CommandCollector.new

    document.update(collector, updated)

    assert_same(
      listener,
      document.instance_variable_get(:@listeners).values.fetch(0)
    )
    refute(
      collector.commands.any? do |command|
        command.is_a?(Mayu::Runtime::Commands::SetListener) ||
          command.is_a?(Mayu::Runtime::Commands::RemoveListener)
      end
    )
  end

  def test_listener_updates_do_not_traverse_the_document
    component = CallbackProbe.new
    initial =
      H[
        :body,
        H[:button, "Click", onclick: H.callback(component, :handle_click)]
      ]
    updated = H[:body, H[:button, "Click", onclick: nil]]
    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root

    document.define_singleton_method(:traverse) do |*|
      raise "listener index performed a full-tree traversal"
    end

    document.update(Mayu::Runtime::VNodes::CommandCollector.new, updated)

    assert_empty(document.instance_variable_get(:@listeners))
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

  def test_queued_continuous_callbacks_run_once_with_the_latest_payload
    received = run_slow_handler("mousemove")

    assert_equal([1, 5], received)
  end

  def test_queued_discrete_callbacks_all_run
    received = run_slow_handler("click")

    assert_equal([1, 2, 3, 4, 5], received)
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

  def test_stopping_a_component_releases_callers_of_calls_it_never_ran
    SlowHandlerProbe.gate = Async::Queue.new
    SlowHandlerProbe.received = []

    run_engine(H[:body, H[SlowHandlerProbe]]) do |engine|
      component = find_component(engine.root, SlowHandlerProbe)
      instance = component.instance_variable_get(:@instance)
      wait_until { instance.instance_variable_get(:@__vnode_queue) }
      listener = nil
      find_element(engine.root, :div).each_listener do |name, candidate|
        listener = candidate if name == "click"
      end

      # The first call blocks in its handler and the second waits behind it.
      running = engine.callback(listener.id, {eventType: "click", n: 1})
      wait_until { SlowHandlerProbe.received.any? }
      queued = engine.callback(listener.id, {eventType: "click", n: 2})

      component.stop

      Async::Task.current.with_timeout(0.5) do
        running.dequeue
        queued.dequeue
      end
      assert_equal([1], SlowHandlerProbe.received)
    end
  end

  def test_settled_callback_is_answered_after_the_patches_of_its_final_state
    run_engine(H[:body, H[SettleProbe]]) do |engine|
      listener = wait_for_listener(engine, SettleProbe)

      engine.callback(listener.id, {}, settle_id: "s1")

      commands = commands_until_settled(engine)
      texts = commands.grep(Mayu::Runtime::Commands::SetTextContent).map(&:content)
      complete =
        commands.index { it.is_a?(Mayu::Runtime::Commands::CallbackComplete) }
      final_text =
        commands.index do
          it.is_a?(Mayu::Runtime::Commands::SetTextContent) &&
          it.content == "Step 2"
        end

      assert_equal(["Step 1", "Step 2"], texts)
      assert_operator(final_text, :<, complete)
      assert_equal("s1", commands[complete].id)
    end
  end

  def test_raising_callback_is_answered_with_callback_failed
    engine =
      Mayu::Runtime::Engine.new(
        H[:body, H[CallbackErrorProbe]],
        metrics: NullMetrics.new,
        render_exceptions: false
      )

    run_engine_instance(engine) do
      listener = engine.root.instance_variable_get(:@listeners).values.first
      engine.callback(listener.id, {}, settle_id: "s1")

      commands = commands_until_settled(engine)

      assert_equal(
        [Mayu::Runtime::Commands::CallbackFailed["s1"]],
        commands.select { settle_command?(it) }
      )
    end
  end

  def test_stale_listener_is_answered_with_callback_failed
    run_engine(H[:body, H[CallbackProbe]]) do |engine|
      engine.callback("stale", {}, settle_id: "s1")

      assert_equal(
        [Mayu::Runtime::Commands::CallbackFailed["s1"]],
        commands_until_settled(engine).select { settle_command?(it) }
      )
    end
  end

  def test_callback_without_settle_id_is_not_answered
    run_engine(H[:body, H[CallbackProbe]]) do |engine|
      listener = wait_for_listener(engine, CallbackProbe)

      engine.callback(listener.id, {})

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      refute(unwrap_commands(batch).any? { settle_command?(it) })
      assert_no_patches(engine)
    end
  end

  def test_callbacks_of_a_stopped_component_fail
    SlowHandlerProbe.gate = Async::Queue.new
    SlowHandlerProbe.received = []

    run_engine(H[:body, H[SlowHandlerProbe]]) do |engine|
      component = find_component(engine.root, SlowHandlerProbe)
      instance = component.instance_variable_get(:@instance)
      wait_until { instance.instance_variable_get(:@__vnode_queue) }
      listener = nil
      find_element(engine.root, :div).each_listener do |name, candidate|
        listener = candidate if name == "click"
      end

      # The first call blocks in its handler and the second waits behind it.
      engine.callback(listener.id, {eventType: "click", n: 1}, settle_id: "running")
      wait_until { SlowHandlerProbe.received.any? }
      engine.callback(listener.id, {eventType: "click", n: 2}, settle_id: "queued")

      component.stop

      settled = []
      until settled.size == 2
        settled.concat(commands_until_settled(engine).select { settle_command?(it) })
      end

      assert_equal(
        [
          Mayu::Runtime::Commands::CallbackFailed["queued"],
          Mayu::Runtime::Commands::CallbackFailed["running"]
        ].sort_by(&:id),
        settled.sort_by(&:id)
      )
      assert_equal([1], SlowHandlerProbe.received)
    end
  end

  private

  def wait_for_listener(engine, component_class)
    instance =
      find_component(engine.root, component_class).instance_variable_get(:@instance)
    listeners = engine.root.instance_variable_get(:@listeners)
    wait_until { listeners.any? && instance.respond_to?(:rerender!) }
    listeners.values.first
  end

  def settle_command?(command)
    command.is_a?(Mayu::Runtime::Commands::CallbackComplete) ||
      command.is_a?(Mayu::Runtime::Commands::CallbackFailed)
  end

  # The commands of every batch up to the one that answers a callback.
  def commands_until_settled(engine, max_batches: 5)
    commands = []
    max_batches.times do
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      commands.concat(unwrap_commands(batch))
      return commands if commands.any? { settle_command?(it) }
    end
    flunk("No CallbackComplete or CallbackFailed in #{max_batches} batches")
  end

  # Sends four events while the handler is blocked on the first one, then
  # lets every handler run and returns the payloads they received.
  def run_slow_handler(event_type)
    SlowHandlerProbe.gate = Async::Queue.new
    SlowHandlerProbe.received = []

    run_engine(H[:body, H[SlowHandlerProbe]]) do |engine|
      document = engine.root
      component = find_component(document, SlowHandlerProbe)
      instance = component.instance_variable_get(:@instance)
      wait_until { instance.instance_variable_get(:@__vnode_queue) }

      listener = nil
      find_element(document, :div).each_listener do |name, candidate|
        listener = candidate if name == event_type
      end

      send = ->(n) { engine.callback(listener.id, {eventType: event_type, n:}) }
      completions = [send.call(1)]
      wait_until { SlowHandlerProbe.received.any? }
      completions += (2..5).map(&send)

      5.times { SlowHandlerProbe.gate.enqueue(true) }
      Async::Task.current.with_timeout(0.5) do
        completions.uniq.each(&:dequeue)
      end
    end

    SlowHandlerProbe.received
  end
end
