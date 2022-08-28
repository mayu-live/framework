# typed: strict

require_relative "environment"

module Mayu
  class Session
    extend T::Sig

    sig { params(environment: Environment, request_path: String).void }
    def initialize(environment, request_path:)
      @environment = environment
      @store = T.let(create_store, State::Store)
      @current_path = request_path
    end

    sig { returns(State::Store) }
    attr_reader :store
    sig { returns(String) }
    attr_reader :current_path

    sig { returns(Fetch) }
    def fetch = @environment.fetch

    sig { params(path: String).void }
    def navigate(path)
      @app = @environment.load_root(path)
      @current_path = path
    end

    private

    sig { returns(State::Store) }
    def create_store
      # In the future we could initialize the state with something already
      # stored somewhere. But for now we start with an empty state.
      @environment.create_store(initial_state: {})
    end
  end
end
