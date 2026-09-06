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
    attr_reader :config, :router, :metrics, :marshaller

    def initialize
      @config = FakeConfig.new
      @router = FakeRouter.new
      @metrics = Mayu::Test::FakeMetrics.new
      @marshaller = nil
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

    def replace_stylesheets(stylesheets)
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
end
