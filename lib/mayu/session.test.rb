#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require "fileutils"
require "tmpdir"

require_relative "session"
require_relative "encrypted_marshal"
require_relative "session/transfer_state"
require_relative "test"

class Mayu::SessionTest < Minitest::Test
  class FakeServerConfig
    def initialize(render_exceptions: true)
      @render_exceptions = render_exceptions
    end

    def hmr? = false
    def render_exceptions? = @render_exceptions
  end

  class FakeConfig
    attr_reader :server

    def initialize(render_exceptions: true)
      @server = FakeServerConfig.new(render_exceptions:)
    end
  end

  class FakeRouter
    def match(_path)
      nil
    end
  end

  class FakeEnvironment
    attr_reader :config, :router, :metrics, :marshaller
    attr_accessor :module_provider

    def initialize(module_provider: nil, render_exceptions: true)
      @config = FakeConfig.new(render_exceptions:)
      @router = FakeRouter.new
      @metrics = Mayu::Test::FakeMetrics.new
      @marshaller = nil
      @module_provider = module_provider
    end

    def subscribe_klenod_updates(&block)
      @subscription = block
    end

    def unsubscribe_klenod_updates(_subscription)
      @subscription = nil
    end
  end

  class FakeEngine
    attr_reader :batches, :refreshed_descriptor, :stylesheets

    def initialize(render_exceptions: true)
      @batches = []
      @render_exceptions = render_exceptions
    end

    def commands
      @batches.flat_map(&:commands)
    end

    def enqueue_command(command)
      enqueue_batch(Mayu::Runtime::Batch[[command]])
    end

    def enqueue_batch(batch)
      @batches << batch
    end

    def render_exceptions? = @render_exceptions

    def refresh(descriptor)
      @refreshed_descriptor = descriptor
    end

    def replace_route_assets(stylesheets:, scripts:)
      @stylesheets = stylesheets
    end
  end

  class ReloadErrorProvider
    attr_reader :rewritten_error

    def rewrite_exception(error)
      @rewritten_error = error
      error.set_backtrace(["app:/broken.haml:2"])
    end
  end

  def test_session_uses_runtime_engine
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {},
        http2: false
      )

    session = Mayu::Session.new(environment: env, request_info: request_info)
    engine = session.instance_variable_get(:@engine)

    assert_instance_of(Mayu::Runtime::Engine, engine)

    html = session.render
    assert_includes(html, "Error: Could not find page")
  end

  def test_session_start_stop
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {},
        http2: false
      )

    session = Mayu::Session.new(environment: env, request_info: request_info)

    Async do
      session.start
      assert(session.running?)
      session.stop
    end.wait

    refute(session.running?)
  end

  def test_events_can_be_queued_before_the_session_starts
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {},
        http2: false
      )
    session = Mayu::Session.new(environment: env, request_info: request_info)
    session.enqueue_event(Mayu::Session::Events::PingEvent[123])

    Async do
      session.start
      batch = Async::Task.current.with_timeout(0.5) { session.dequeue_batch }
      assert_equal([Mayu::Runtime::Commands::Pong[123]], batch.commands)
    ensure
      session.stop
    end.wait
  end

  def test_invalid_event_messages_are_rejected
    assert_raises(Mayu::Session::Events::InvalidEventError) do
      Mayu::Session::Events.parse(["Callback", "", {}, 1])
    end
  end

  def test_legacy_json_event_objects_are_rejected
    assert_raises(Mayu::Session::Events::InvalidEventError) do
      Mayu::Session::Events.parse({type: "ping", ping: 1})
    end
  end

  def test_callback_message_parses_to_one_typed_event
    event =
      Mayu::Session::Events.parse(
        ["Callback", "listener", {type: "click"}, 123]
      )

    assert_equal(
      Mayu::Session::Events::CallbackEvent[
        "listener",
        {type: "click"},
        123
      ],
      event
    )
  end

  def test_receive_message_queues_exactly_one_event
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {},
        http2: false
      )
    session = Mayu::Session.new(environment: env, request_info: request_info)
    queue = session.instance_variable_get(:@incoming_events)

    session.receive_message(["Navigate", "/next", true, 123])

    Async do
      event = Async::Task.current.with_timeout(0.5) { queue.dequeue }
      assert_equal(
        Mayu::Session::Events::NavigateEvent["/next", true, 123],
        event
      )
      assert(queue.empty?)
    end.wait
  end

  def test_session_renders_the_example_through_klenod
    provider =
      Mayu::Klenod::Configuration.new(
        root: File.expand_path("../../example", __dir__)
      ).development_provider
    env = FakeEnvironment.new(module_provider: provider)
    request_info =
      Mayu::Session::RequestInfo.new(path: "/", headers: {}, http2: false)

    session = Mayu::Session.new(environment: env, request_info: request_info)
    html = session.render

    assert_equal(200, session.route_status)
    assert_includes(html, "<!DOCTYPE html>")
    assert_includes(html, "/.mayu/assets/")
    refute_includes(html, "Mayu.callback(event,")
    refute_includes(html, "data-mayu-on")
    refute_empty(session.listener_commands)
  end

  def test_session_renders_klenod_slots
    provider =
      Mayu::Klenod::Configuration.new(
        root: File.expand_path("../../example", __dir__)
      ).development_provider
    env = FakeEnvironment.new(module_provider: provider)
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/demos/form",
        headers: {},
        http2: false
      )

    html =
      Mayu::Session.new(environment: env, request_info: request_info).render

    assert_includes(html, "Form demo")
    assert_includes(html, "Pokémon")
  end

  def test_session_renders_the_exception_examples
    provider =
      Mayu::Klenod::Configuration.new(
        root: File.expand_path("../../example", __dir__)
      ).development_provider
    env = FakeEnvironment.new(module_provider: provider)
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/demos/exceptions",
        headers: {},
        http2: false
      )

    session = Mayu::Session.new(environment: env, request_info: request_info)
    html = session.render

    assert_includes(html, "Callback exception")
    assert_includes(html, "Render exception")
    assert_includes(html, "The child is rendering normally")
    refute_empty(session.listener_commands)
  end

  def test_encrypted_transfer_restores_klenod_component_references
    root = File.expand_path("../../example", __dir__)
    marshaller = Mayu::EncryptedMarshal.new("transfer-test-secret")
    source_environment =
      FakeEnvironment.new(
        module_provider:
          Mayu::Klenod::Configuration.new(root:).development_provider
      )
    source_environment.instance_variable_set(:@marshaller, marshaller)
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/demos/form",
        headers: {},
        http2: false
      )
    session = Mayu::Session.new(environment: source_environment, request_info:)

    encrypted =
      Mayu::Session::TransferState.from_session(session).encrypt(marshaller)
    target_environment =
      FakeEnvironment.new(
        module_provider:
          Mayu::Klenod::Configuration.new(root:).development_provider,
        render_exceptions: false
      )
    target_environment.instance_variable_set(:@marshaller, marshaller)
    restored =
      Mayu::Session::TransferState.decrypt(marshaller, encrypted).resume(
        target_environment
      )

    assert_equal(session.id, restored.id)
    assert_includes(restored.render, "Form demo")
    assert_equal(target_environment.module_provider, restored.module_provider)

    engine = restored.instance_variable_get(:@engine)
    refute(engine.render_exceptions?)
    Async do
      engine.start
      listener =
        engine
          .root
          .instance_variable_get(:@listeners)
          .values
          .find { it.callback&.method_name == :handle_enable }

      refute_nil(listener)
      engine.callback(listener.id, {target: {value: "Elements"}})
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      refute_nil(batch)
    ensure
      engine.stop
    end.wait
  end

  def test_session_renders_klenod_jsx_custom_elements
    provider =
      Mayu::Klenod::Configuration.new(
        root: File.expand_path("../../example", __dir__)
      ).development_provider
    env = FakeEnvironment.new(module_provider: provider)
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/demos/custom-elements",
        headers: {},
        http2: false
      )

    html =
      Mayu::Session.new(environment: env, request_info: request_info).render

    assert_includes(html, "<klenod-")
    assert_includes(html, "CustomElement_jsx")
    assert_includes(html, "Custom elements")
  end

  def test_session_renders_example_optional_catch_all_route_segments
    provider =
      Mayu::Klenod::Configuration.new(
        root: File.expand_path("../../example", __dir__)
      ).development_provider
    env = FakeEnvironment.new(module_provider: provider)
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/demos/segments/alpha/beta",
        headers: {},
        http2: false
      )

    html = Mayu::Session.new(environment: env, request_info:).render

    assert_includes(html, "Route segments")
    assert_includes(html, "Segments: alpha / beta")
  end

  def test_session_renders_the_klenod_error_view_after_page_resolution_failure
    Dir.mktmpdir("mayu-klenod-error") do |root|
      pages = File.join(root, "app", "pages")
      FileUtils.mkdir_p(pages)
      File.write(File.join(root, "app", "root.haml"), "%slot\n")
      File.write(File.join(pages, "+page.rb"), "raise \"boom\"\n")
      File.write(File.join(pages, "+error.haml"), "%p= $error.message\n")

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      env = FakeEnvironment.new(module_provider: provider)
      request_info =
        Mayu::Session::RequestInfo.new(path: "/", headers: {}, http2: false)

      session = Mayu::Session.new(environment: env, request_info: request_info)

      assert_equal(500, session.route_status)
      assert_includes(session.render, "boom")
    end
  end

  def test_reload_success_emits_reload_succeeded_command
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {},
        http2: false
      )
    session = Mayu::Session.new(environment: env, request_info: request_info)
    fake_engine = FakeEngine.new
    session.instance_variable_set(:@engine, fake_engine)

    reload_result = Struct.new(:errors) { def success? = true }.new([])

    session.send(:handle_reload_result, reload_result)

    assert(fake_engine.refreshed_descriptor)
    command =
      fake_engine.commands.find do |candidate|
        candidate.is_a?(Mayu::Runtime::Commands::ReloadSucceeded)
      end

    refute_nil(command)
  end

  def test_klenod_reload_failure_emits_render_error_batch
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {},
        http2: false
      )
    session = Mayu::Session.new(environment: env, request_info: request_info)
    provider = ReloadErrorProvider.new
    env.module_provider = provider
    fake_engine = FakeEngine.new
    session.instance_variable_set(:@engine, fake_engine)

    error = SyntaxError.new("unexpected token")
    error.define_singleton_method(:module_id) { "app:/broken.haml" }
    error.define_singleton_method(:source) { "%p= )\n" }
    error.set_backtrace(["generated:/broken.rb:20"])
    reload_result =
      Struct
        .new(:errors) { def success? = false }
        .new([["app:/broken.haml", error]])

    session.send(:handle_reload_result, reload_result)

    assert_equal(1, fake_engine.batches.length)
    command = fake_engine.commands.first
    assert_instance_of(Mayu::Runtime::Commands::RenderError, command)
    assert_equal("app:/broken.haml", command.file)
    assert_equal("SyntaxError", command.type)
    assert_equal("unexpected token", command.message)
    assert_equal("%p= )\n", command.source)
    assert_equal(["app:/broken.haml:2"], command.backtrace)
    assert_same(error, provider.rewritten_error)
  end

  def test_klenod_reload_error_overlay_can_be_disabled
    env = FakeEnvironment.new(render_exceptions: false)
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {},
        http2: false
      )
    session = Mayu::Session.new(environment: env, request_info: request_info)
    fake_engine = FakeEngine.new(render_exceptions: false)
    session.instance_variable_set(:@engine, fake_engine)

    error = SyntaxError.new("unexpected token")
    reload_result =
      Struct
        .new(:errors) { def success? = false }
        .new([["app:/broken.haml", error]])

    session.send(:handle_reload_result, reload_result)

    assert_empty(fake_engine.batches)
  end
end
