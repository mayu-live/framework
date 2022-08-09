# typed: false

require_relative "../mayu"
require_relative "environment"
require_relative "state/loader"
require_relative "metrics"

require_relative "server/assets_app"
require_relative "server/callback_handler_app"
require_relative "server/event_stream_app"
require_relative "server/init_session_app"
require_relative "server/resume_app"
require_relative "server/ping_handler_callback"

module Mayu
  module Server
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

      Rack::Builder.new do
        use Rack::CommonLogger

        use Metrics::Middleware::Collector,
            registry: environment.prometheus_registry

        map EventStreamApp::MOUNT_PATH do
          run EventStreamApp.new
        end

        map CallbackHandlerApp::MOUNT_PATH do
          run CallbackHandlerApp.new
        end

        map ResumeApp::MOUNT_PATH do
          run ResumeApp.new
        end

        map AssetsApp::MOUNT_PATH do
          run AssetsApp.new
        end

        use Rack::Static, Mayu::Server.rack_static_options_for_js

        use Rack::Static, urls: [""], root: public_root_dir, cascade: true

        run InitSessionApp.new(environment)
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
