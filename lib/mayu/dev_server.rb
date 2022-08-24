# typed: true

require "rack/brotli"

require_relative "../mayu"
require_relative "environment"
require_relative "state/loader"
require_relative "metrics"

require "mayu/edge/server"
require_relative "dev_server/assets_app"

module Mayu
  module DevServer
    JS_ROOT_DIR = File.join(File.dirname(__FILE__), "client", "dist")
    APP_DIR = "app"
    PUBLIC_DIR = "public"
    STORE_DIR = "store"

    def self.rack_static_options_for_js
      urls =
        Dir[File.join(JS_ROOT_DIR, "*.js")]
          .map { File.basename(_1) }
          .map { ["/__mayu/#{_1}", _1] }
          .to_h
          .merge("/__mayu.serviceWorker.js" => "sw.js")
      { root: JS_ROOT_DIR, urls: }
    end

    def self.build(root:, hot_reload:)
      region = ENV.fetch("FLY_REGION", "localhost")
      public_root_dir = File.join(root, PUBLIC_DIR)
      environment = Environment.new(root:, region:, hot_reload:)
      metrics = {}

      Rack::Builder.new do
        T.bind(self, Rack::Builder)

        use Rack::CommonLogger

        use Rack::Brotli,
            include: %w[text/css text/html text/javascript text/plain]

        use Rack::Deflater, include: %w[text/event-stream]

        use Metrics::Middleware::Collector,
            registry: environment.prometheus_registry

        map "/__mayu/api/events" do
          run Edge::Server::EventStreamApp.new(environment:)
        end

        map "/__mayu/api/callback" do
          run Edge::Server::CallbackApp.new(environment:)
        end

        map "/__mayu/api/resume" do
          run Edge::Server::ResumeSessionApp.new(environment:)
        end

        map AssetsApp::MOUNT_PATH do
          run AssetsApp.new
        end

        use Rack::Static, DevServer.rack_static_options_for_js

        use Rack::Static, urls: [""], root: public_root_dir, cascade: true

        run Edge::Server::InitSessionApp.new(environment:, metrics:)
      end
    end

    def self.build_metrics_app(root:)
      region = ENV.fetch("FLY_REGION", "localhost")
      environment = Environment.new(root:, region:, hot_reload: false)

      Rack::Builder.new do
        use Rack::CommonLogger

        use Rack::Deflater

        use Metrics::Middleware::Collector,
            registry: environment.prometheus_registry
        use Metrics::Middleware::Exporter,
            registry: environment.prometheus_registry

        run ->(_) { [200, { "content-type" => "text/html" }, ["ok"]] }
      end
    end
  end
end
