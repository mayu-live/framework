# typed: strict

require "async"
require "async/http/internet"
require_relative "vdom"
require_relative "state/store"
require_relative "state/loader"
require_relative "routes"
require_relative "metrics"
require_relative "modules2/system"
require_relative "fetch"
require_relative "message_cipher"

module Mayu
  class Environment
    class Config < T::Struct
      extend T::Sig

      sig do
        params(mayu_config: T::Hash[Symbol, T.untyped]).returns(
          T.attached_class
        )
      end
      def self.from_env(mayu_config = {})
        new(
          SECRET_KEY: fetch_env("SECRET_KEY"),
          MAX_SESSIONS: mayu_config[:max_sessions],
          KEEPALIVE_SECONDS: mayu_config[:keepalive_seconds],
          PRINT_CAPACITY_INTERVAL: mayu_config[:print_capacity_interval],
          HEARTBEAT_INTERVAL_SECONDS: mayu_config[:heartbeat_interval],
          FLY_APP_NAME: fetch_env("FLY_APP_NAME"),
          FLY_ALLOC_ID: fetch_env("FLY_ALLOC_ID"),
          FLY_REGION: fetch_env("FLY_REGION")
        )
      end

      sig { params(name: String).returns(String) }
      def self.fetch_env(name)
        ENV.fetch(name) { raise "#{name} is not set" }
      end

      const :SECRET_KEY, String
      const :MAX_SESSIONS, Integer, default: 16
      const :PRINT_CAPACITY_INTERVAL, Float, default: 5.0
      const :HEARTBEAT_INTERVAL_SECONDS, Float, default: 0.5
      const :KEEPALIVE_SECONDS, Float, default: 3.0

      const :FLY_APP_NAME, String
      const :FLY_ALLOC_ID, String
      const :FLY_REGION, String
    end

    # The Environment class is instantiated on startup and contains
    # configuration and everything that should be shared.
    extend T::Sig

    APP_DIR = "app"
    STORE_DIR = "store"

    sig { returns(String) }
    attr_reader :root
    sig { returns(Config) }
    attr_reader :config
    sig { returns(T::Array[Routes::Route]) }
    attr_reader :routes
    sig { returns(State::Store::Reducers) }
    attr_reader :reducers
    sig { returns(Modules2::System) }
    attr_reader :modules
    sig { returns(Prometheus::Client::Registry) }
    attr_reader :prometheus_registry
    sig { returns(Fetch) }
    attr_reader :fetch
    sig { returns(MessageCipher) }
    attr_reader :message_cipher

    sig { params(root: String, config: Config, hot_reload: T::Boolean).void }
    def initialize(root:, config:, hot_reload: false)
      @root = T.let(File.absolute_path(root), String)
      @config = config
      @message_cipher =
        T.let(MessageCipher.new(key: config.SECRET_KEY), MessageCipher)
      # TODO: Reload routes when things change in /pages...
      # probably have to set up an async task...
      @routes =
        T.let(
          Routes.build_routes(File.join(@root, APP_DIR)),
          T::Array[Routes::Route]
        )
      @reducers =
        T.let(
          State::Loader.new(File.join(@root, STORE_DIR)).load,
          State::Store::Reducers
        )
      @modules =
        T.let(
          Modules2::System.new(@root), #,, enable_code_reloader: hot_reload),
          Modules2::System
        )
      @prometheus_registry =
        T.let(Metrics::PrometheusRegistry.new, Prometheus::Client::Registry)
      @fetch = T.let(Fetch.new, Fetch)
    end

    sig do
      params(initial_state: T::Hash[Symbol, T.untyped]).returns(State::Store)
    end
    def create_store(initial_state: {})
      State::Store.new(initial_state, reducers:)
    end

    sig { params(request_path: String).returns(VDOM::Descriptor) }
    def load_root(request_path)
      # We should match the route earlier, so that we don't have to get this
      # far in case it doesn't match...
      route_match = match_route(request_path)

      # Load the page component.
      modules.load_page(route_match.template).type =>
        Modules2::ModuleTypes::Ruby => mod_type
      page_component = mod_type.klass

      # Apply the layouts.
      route_match
        .layouts
        .reverse
        .reduce(VDOM.h[page_component]) do |app, layout|
          layout_component = modules.load_page(layout).klass
          VDOM.h[layout_component, T.cast(app, VDOM::Descriptor)]
        end
    end

    sig { params(path: String).returns(String) }
    def self.normalize_path(path)
      File.absolute_path(path).delete_prefix!(root) or
        raise ArgumentError, "Path #{path} is not in project root"
    end

    sig { params(request_path: String).returns(Routes::RouteMatch) }
    def match_route(request_path)
      Routes.match_route(@routes, request_path)
    end
  end
end
