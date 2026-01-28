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

  def test_session_uses_vnodes2_engine
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {
        },
        http2: false
      )

    ENV["MAYU_VNODES2"] = "1"

    session = Mayu::Session.new(environment: env, request_info: request_info)
    engine = session.instance_variable_get(:@engine)

    assert_instance_of(Mayu::Runtime::VNodes2::Engine, engine)

    html = session.render
    assert_includes(html, "Error: Could not find page")
  ensure
    ENV.delete("MAYU_VNODES2")
  end

  def test_session_start_stop_with_vnodes2
    env = FakeEnvironment.new
    request_info =
      Mayu::Session::RequestInfo.new(
        path: "/missing",
        headers: {
        },
        http2: false
      )

    ENV["MAYU_VNODES2"] = "1"

    session = Mayu::Session.new(environment: env, request_info: request_info)

    Async do
      session.start
      assert(session.running?)
      session.stop
    end.wait

    refute(session.running?)
  ensure
    ENV.delete("MAYU_VNODES2")
  end
end
