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
    def hmr? = false
  end

  class FakeConfig
    attr_reader :server

    def initialize
      @server = FakeServerConfig.new
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

    def initialize(module_provider: nil)
      @config = FakeConfig.new
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
    attr_reader :patches, :refreshed_descriptor, :stylesheets

    def initialize
      @patches = []
    end

    def patch(patch)
      @patches.concat(Array(patch))
    end

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
        headers: {
        },
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
        headers: {
        },
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
    assert_includes(html, "Mayu.callback(event,")
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
        headers: {
        },
        http2: false
      )

    html =
      Mayu::Session.new(environment: env, request_info: request_info).render

    assert_includes(html, "Form demo")
    assert_includes(html, "Pokémon")
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
        headers: {
        },
        http2: false
      )
    session = Mayu::Session.new(environment: source_environment, request_info:)

    encrypted =
      Mayu::Session::TransferState.from_session(session).encrypt(marshaller)
    target_environment =
      FakeEnvironment.new(
        module_provider:
          Mayu::Klenod::Configuration.new(root:).development_provider
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
    Async do
      engine.start
      listener =
        engine
          .root
          .instance_variable_get(:@listeners)
          .values
          .find { it.callback&.method_name == :handle_enable }

      refute_nil(listener)
      engine.callback(listener.id, { target: { value: "Elements" } })
      patch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      refute_nil(patch)
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
        headers: {
        },
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
        headers: {
        },
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

  def test_reload_success_emits_clear_error_event_patch
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {
        },
        http2: false
      )
    session = Mayu::Session.new(environment: env, request_info: request_info)
    fake_engine = FakeEngine.new
    session.instance_variable_set(:@engine, fake_engine)

    reload_result = Struct.new(:errors) { def success? = true }.new([])

    session.send(:handle_reload_result, reload_result)

    assert(fake_engine.refreshed_descriptor)
    event_patch =
      fake_engine.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::Event)
      end

    refute_nil(event_patch)
    assert_equal("reload:success", event_patch.event)
    assert_nil(event_patch.payload)
  end

  def test_klenod_reload_failure_emits_render_error_patch
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {
        },
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

    patch = fake_engine.patches.first
    assert_instance_of(Mayu::Runtime::Patches::RenderError, patch)
    assert_equal("app:/broken.haml", patch.file)
    assert_equal("SyntaxError", patch.type)
    assert_equal("unexpected token", patch.message)
    assert_equal("%p= )\n", patch.source)
    assert_equal(["app:/broken.haml:2"], patch.backtrace)
    assert_same(error, provider.rewritten_error)
  end
end
