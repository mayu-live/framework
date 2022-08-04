# typed: strict

require_relative "state/store"
require_relative "routes"
require_relative "modules/system"

module Mayu
  class Environment
    extend T::Sig

    APP_DIR = 'app'
    STORE_DIR = 'store'

    sig {returns(String)}
    attr_reader :root
    sig {returns(T::Array[Routes::Route])}
    attr_reader :routes
    sig {returns(State::Store::Reducers)}
    attr_reader :reducers
    sig {returns(Modules::System)}
    attr_reader :modules

    sig {params(root: String, hot_reload: T::Boolean).void}
    def initialize(root:, hot_reload: false)
      @root = root
      @routes = T.let(
        Routes.build_routes(File.join(root, APP_DIR)),
        T::Array[Routes::Route]
      )
      @reducers = T.let(State::Loader.new(File.join(root, STORE_DIR)).load, State::Store::Reducers)
      @modules = T.let(Modules::System.new(root, enable_code_reloader: hot_reload), Modules::System)
    end

    sig{params(initial_state: T::Hash[Symbol, T.untyped]).returns(State::Store)}
    def create_store(initial_state: {})
      State::Store.new(initial_state, reducers:)
    end

    sig { params(request_path: String).returns(VDOM::Descriptor) }
    def load_root(request_path)
      # We should match the route earlier, so that we don't have to get this
      # far in case it doesn't match...
      route_match = match_route(request_path)

      # Load the page component.
      page_component = modules.load_page(route_match.template).klass

      # Apply the layouts.
      route_match.layouts.reverse.reduce(VDOM.h(page_component)) do |app, layout|
        layout_component = modules.load_page(layout).klass
        VDOM.h(layout_component, {}, [app])
      end
    end

    sig{params(request_path: String).returns(Routes::RouteMatch)}
    def match_route(request_path)
      Routes.match_route(@routes, request_path)
    end
  end
end
