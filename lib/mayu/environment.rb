# typed: strict

require "async"
require "async/http/internet"
require_relative "vdom"
require_relative "state/store"
require_relative "state/loader"
require_relative "routes"
require_relative "metrics"
require_relative "app_metrics"
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
    sig { returns(Fetch) }
    attr_reader :fetch
    sig { returns(MessageCipher) }
    attr_reader :message_cipher
    sig { returns(AppMetrics) }
    attr_reader :metrics

    sig { params(config: Configuration, metrics: AppMetrics).void }
    def initialize(config, metrics)
      @root = T.let(config.root, String)
      @app_root = T.let(File.join(config.root, "app"), String)
      @config = config
      @message_cipher =
        T.let(MessageCipher.new(config.secret_key, ttl: 30), MessageCipher)
      # TODO: Reload routes when things change in /pages...
      # Should probably make routes into a resource type.
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
          if @config.use_bundle
            Resources::Registry.load(
              File.read(@config.paths.bundle_filename, encoding: "binary"),
              root:
            )
          else
            Resources::Registry.new(root: @root)
          end,
          Resources::Registry
        )
      @metrics = metrics
      @fetch = T.let(Fetch.new, Fetch)
      @init_js = T.let(nil, T.nilable(String))
    end

    sig { returns(String) }
    def init_js
      @init_js ||=
        JSON.parse(File.read(File.join(js_runtime_path, "entries.json"))).fetch(
          "main"
        )
    end

    sig { params(name: Symbol).returns(String) }
    def path(name)
      File.join(@root, @config.paths.send(name))
    end

    sig { returns(String) }
    def js_runtime_path
      File.join(__dir__, "client", "dist")
    end

    sig do
      params(initial_state: T::Hash[Symbol, T.untyped]).returns(State::Store)
    end
    def create_store(initial_state: {})
      State::Store.new(initial_state, reducers:)
    end

    sig do
      params(request_path: String, headers: T::Hash[String, String]).returns(
        VDOM::Descriptor
      )
    end
    def load_root(request_path, headers: {})
      path, search = request_path.split("?", 2)
      # We should match the route earlier, so that we don't have to get this
      # far in case it doesn't match...
      route_match = match_route(path.to_s)
      query = Rack::Utils.parse_nested_query(search).transform_keys(&:to_sym)
      params = route_match.params

      # Load the page component.
      component_path = File.join("/", "app", "pages", route_match.template)
      resources.load_resource(component_path).type =>
        Resources::Types::Component => mod_type

      page_component = mod_type.component

      resources.load_resource(File.join("/", "app", "root")).type =>
        Resources::Types::Component => root

      request_info = { path:, params:, query:, headers: }.freeze

      # Apply the layouts.
      # NOTE: Pages should probably be their own
      # resource type and load their layouts.
      route_match
        .layouts
        .reverse
        .reduce(VDOM::H[page_component, request: request_info]) do |app, layout|
          Console.logger.info(self, "Applying layout #{layout.inspect}")

          resources.load_resource(
            File.join("/", "app", "pages", layout)
          ).type => Resources::Types::Component => layout

          VDOM::H[layout.component, app, request: request_info]
        end
        .then { VDOM::H[root.component, _1] }
    end

    sig { params(request_path: String).returns(Routes::RouteMatch) }
    def match_route(request_path)
      Routes.match_route(@routes, request_path)
    end
  end
end
