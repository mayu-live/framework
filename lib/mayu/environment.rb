# typed: strict

require "async"
require "async/http/internet"
require_relative "vdom"
require_relative "state/store"
require_relative "state/loader"
require_relative "routes"
require_relative "metrics"
require_relative "resources/system"
require_relative "fetch"
require_relative "message_cipher"
require_relative "configuration"

module Mayu
  class Environment
    # The Environment class is instantiated on startup and contains
    # configuration and everything that should be shared.
    extend T::Sig

    PAGES_DIR = "pages"
    STORE_DIR = "store"

    sig { returns(String) }
    attr_reader :root
    sig { returns(Configuration) }
    attr_reader :config
    sig { returns(T::Array[Routes::Route]) }
    attr_reader :routes
    sig { returns(State::Store::Reducers) }
    attr_reader :reducers
    sig { returns(Resources::System) }
    attr_reader :resources
    sig { returns(Prometheus::Client::Registry) }
    attr_reader :prometheus_registry
    sig { returns(Fetch) }
    attr_reader :fetch
    sig { returns(MessageCipher) }
    attr_reader :message_cipher

    sig { params(config: Configuration).void }
    def initialize(config)
      @root = T.let(config.root, String)
      @config = config
      @message_cipher =
        T.let(MessageCipher.new(key: config.secret_key), MessageCipher)
      # TODO: Reload routes when things change in /pages...
      # probably have to set up an async task...
      @routes =
        T.let(
          Routes.build_routes(File.join(@root, PAGES_DIR)),
          T::Array[Routes::Route]
        )
      @reducers =
        T.let(
          State::Loader.new(File.join(@root, STORE_DIR)).load,
          State::Store::Reducers
        )
      @resources =
        T.let(
          Resources::System.new(@root), #,, enable_code_reloader: hot_reload),
          Resources::System
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
      resources.load_page(route_match.template).type =>
        Resources::Types::Ruby => mod_type

      page_component = mod_type.klass

      # Apply the layouts.
      route_match
        .layouts
        .reverse
        .reduce(VDOM.h[page_component]) do |app, layout|
          layout_component = resources.load_page_component(layout)
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
