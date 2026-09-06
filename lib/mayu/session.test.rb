#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"

require_relative "session"
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
    attr_reader :config, :router, :metrics, :marshaller, :module_provider

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
  end

  def test_reload_failure_emits_render_error_patch
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

    reload_failure =
      Mayu::Modules::System::ReloadFailure[
        "/c.rb",
        "SyntaxTree::Parser::ParseError",
        "unexpected token",
        ["/c.rb:1:1"],
        "Dep = import(\n",
        1,
        1
      ]
    reload_result =
      Mayu::Modules::System::ReloadResult[[], [], [reload_failure]]

    session.send(:handle_reload_result, reload_result)

    assert_equal(1, fake_engine.patches.length)
    patch = fake_engine.patches.first

    assert_instance_of(Mayu::Runtime::Patches::RenderError, patch)
    assert_equal("/c.rb", patch.file)
    assert_equal("SyntaxTree::Parser::ParseError", patch.type)
    assert_equal("unexpected token", patch.message)
    assert_equal(["/c.rb:1:1"], patch.backtrace)
    assert_equal("Dep = import(\n", patch.source)
    assert_equal([{ name: "CodeReload", path: "/c.rb" }], patch.tree_path)
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

    reload_result = Mayu::Modules::System::ReloadResult[["/c.rb"], [], []]

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
    fake_engine = FakeEngine.new
    session.instance_variable_set(:@engine, fake_engine)

    error =
      Struct
        .new(:module_id, :source, :cause) do
          def message = "unexpected token"
          def backtrace = ["app:/broken.haml:2"]
        end
        .new("app:/broken.haml", "%p= )\n", SyntaxError.new)
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
  end
end
