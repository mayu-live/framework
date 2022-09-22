# typed: strict

require "async"
require "async/http/internet"
require_relative "vdom"
require_relative "state/store"
require_relative "state/loader"
require_relative "routes"
require_relative "metrics"
require_relative "resources/registry"
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
    sig { returns(Resources::Registry) }
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
      @app_root = T.let(File.join(config.root, "app"), String)
      @config = config
      @message_cipher =
        T.let(MessageCipher.new(key: config.secret_key), MessageCipher)
      # TODO: Reload routes when things change in /pages...
      # probably have to set up an async task...
      @routes =
        T.let(
          Routes.build_routes(File.join(@app_root, PAGES_DIR)),
          T::Array[Routes::Route]
        )
      @reducers =
        T.let(
          State::Loader.new(File.join(@app_root, STORE_DIR)).load,
          State::Store::Reducers
        )
      @resources =
        T.let(
          Resources::Registry.new(root: @root), #,, enable_code_reloader: hot_reload),
          Resources::Registry
        )
      @prometheus_registry =
        T.let(Metrics::PrometheusRegistry.new, Prometheus::Client::Registry)
      @fetch = T.let(Fetch.new, Fetch)
      @init_js = T.let(nil, T.nilable(String))
    end

    sig { returns(String) }
    def init_js
      @init_js ||=
        begin
          @resources.add_resource(
            File.join("/", "vendor", "mayu", "live.js")
          ).type => Resources::Types::JavaScript => type
          type.assets => [asset]
          type.generate_assets(path(:assets)).first
          asset.filename
        end
    end

    sig { params(name: Symbol).returns(String) }
    def path(name)
      File.join(@root, @config.paths.send(name))
    end

    sig do
      params(initial_state: T::Hash[Symbol, T.untyped]).returns(State::Store)
    end
    def create_store(initial_state: {})
      State::Store.new(initial_state, reducers:)
    end

    sig { params(request_path: String).returns(VDOM::Descriptor) }
    def load_root(request_path)
      path, search = request_path.split("?", 2)
      # We should match the route earlier, so that we don't have to get this
      # far in case it doesn't match...
      route_match = match_route(path.to_s)
      query = Rack::Utils.parse_nested_query(search).transform_keys(&:to_sym)
      params = route_match.params

      # Load the page component.
      path = File.join("/", "app", "pages", route_match.template)
      resources.load_resource(
        File.join("/", "app", "pages", route_match.template)
      ).type => Resources::Types::Component => mod_type

      page_component = mod_type.component

      # Apply the layouts.
      # NOTE: Pages should probably be their own
      # resource type and load their layouts.
      route_match
        .layouts
        .reverse
        .reduce(
          VDOM.h2(page_component, path:, params:, query:)
        ) do |app, layout|
          p "Applying layout #{layout.inspect} to #{app.inspect}"
          resources.load_resource(
            File.join("/", "app", "pages", layout)
          ).type => Resources::Types::Component => layout
          p layout

          VDOM.h2(layout.component, app, path:, params:, query:)
        end
    end

    sig { params(request_path: String).returns(Routes::RouteMatch) }
    def match_route(request_path)
      Routes.match_route(@routes, request_path)
    end
  end
end
