# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "server/config"
require_relative "renderer"
require_relative "environment"
require_relative "dev_server/fake_nats"

class TestRenderer < Minitest::Test
  class MyComponent < Mayu::VDOM::Component::Base
    def render
      h.div { h.h1 "hello world" }.div
    end
  end

  def test_renderer
    Sync do
      root = Mayu::VDOM::Descriptor.new(MyComponent, {}, [])

      setup_environment(root) do |environment|
        renderer = Mayu::Renderer.new(environment:, request_path: "/")

        renderer.initial_render => { html:, ids:, stylesheets: }

        p html
      end
    end
  end

  private

  def setup_environment(root_component)
    config =
      Mayu::Server::Config.new(
        FLY_REGION: "dev",
        FLY_ALLOC_ID: SecureRandom.uuid,
        FLY_APP_NAME: "mayu-test",
        SECRET_KEY: "test",
        NATS_SERVER: "",
        MAX_SESSIONS: 1,
        PRINT_CAPACITY_INTERVAL: 1.0,
        HEARTBEAT_INTERVAL_SECONDS: 1.0,
        KEEPALIVE_SECONDS: 3.0
      )
    cluster =
      Mayu::Server::Cluster.new(
        :test,
        config:,
        nats: Mayu::DevServer::FakeNATS::Client.new
      )

    # TODO: Make an Environment interface and implement a TestEnvironment class
    environment =
      Mayu::Environment.new(
        region: "test",
        root: "",
        cluster:,
        hot_reload: false
      )

    environment.stub(:load_root, root_component) { yield environment }
  end
end
