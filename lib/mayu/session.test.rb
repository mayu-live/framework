#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"

require_relative "session"

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
      @metrics = nil
      @marshaller = nil
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
end
