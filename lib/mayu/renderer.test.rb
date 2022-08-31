# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "server/config"
require_relative "renderer"
require_relative "environment"
require_relative "dev_server/fake_nats"

class TestRenderer < Minitest::Test
  class FooComponent < Mayu::VDOM::Component::Base
    initial_state { |props| { count: 0 } }

    mount do
      loop do
        update { |state| { count: state[:count] + 1 } }

        sleep 0.1
      end
    end

    def render
      h.div { h.p "Hello #{state[:count]}" }.div
    end
  end

  class MyComponent < Mayu::VDOM::Component::Base
    def render
      h
        .div do
          h.h1 "hello world"
          h[FooComponent]
        end
        .div
    end
  end

  class PageComponent < Mayu::VDOM::Component::Base
    initial_state { |props| { page: 0 } }

    handler(:set_page) { |e, page| update(page:) }

    def render
      h
        .div do
          h.button "Page 0", on_click: handler(:set_page, 0)
          h.button "Page 1", on_click: handler(:set_page, 1)

          case state[:page]
          when 0
            h[MyComponent]
          when 1
            h[FooComponent]
          else
            h.p "Unknown page"
          end
        end
        .div
    end
  end

  def test_renderer
    Sync do
      root = Mayu::VDOM::Descriptor.new(PageComponent, {}, [])

      setup_environment(root) do |environment|
        renderer = Mayu::Renderer.new(environment:, request_path: "/")

        renderer.initial_render => { html:, ids:, stylesheets:, vtree: }
        puts html
        handlers = html.scan(/&#39;([[:xdigit:]]+)&#39;/).flatten

        renderer2 = Mayu::Renderer.new(environment:, request_path: "/", vtree:)

        x = 0

        on_finish = Async::Condition.new

        update_task =
          renderer2.run do |msg|
            if x > 0
              handler = handlers[(x / 2) % handlers.length]
              puts "Calling handler #{handler}"
              renderer2.handle_callback(handler, {})
            end

            on_finish.signal if x > 10

            x += 1
          end

        on_finish.wait
        update_task.stop

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
