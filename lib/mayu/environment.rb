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

    sig {params(root: String).void}
    def initialize(root:)
      @root = root
      @routes = T.let(
        Routes.build_routes(File.join(root, APP_DIR)),
        T::Array[Routes::Route]
      )
      @reducers = T.let(State::Loader.new(File.join(root, STORE_DIR)).load, State::Store::Reducers)
      @modules = T.let(Modules::System.new(root), Modules::System)
    end

    sig{params(request_path: String).returns(Routes::RouteMatch)}
    def match_route(request_path)
      Routes.match_route(@routes, request_path)
    end

    sig{params(initial_state: T::Hash[Symbol, T.untyped]).returns(State::Store)}
    def create_store(initial_state: {})
      State::Store.new(initial_state, reducers:)
    end
  end
end
