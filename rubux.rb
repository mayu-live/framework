# typed: true

require "async"
require "bundler"
require "pry"
require "sorbet-runtime"

module Rubux
  extend T::Sig

  State = T.type_alias { T::Hash[Symbol, T.untyped] }
  Action = T.type_alias { { type: Symbol, payload: T.untyped } }
  ReducerProc =
    T.type_alias { T.proc.params(state: State, action: Action).returns(State) }
  MiddlewareSetupProc =
    T.type_alias { T.proc.params(store: Store).returns(MiddlewareProcessProc) }
  MiddlewareProcessProc =
    T.type_alias { T.proc.params(action: Action).returns(State) }

  sig { params(reducers: ReducerProc).returns(ReducerProc) }
  def self.combine_reducers(**reducers)
    T.cast(
      ->(state, action) do
        reducers.reduce({}) do |new_state, (name, reducer)|
          new_state.merge(name => reducer.call(state[name], action))
        end
      end,
      ReducerProc
    )
  end

  # const thunk = store => next => action =>
  # typeof action === 'function'
  #   ? action(store.dispatch, store.getState)
  #   : next(action)

  module MiddlewareBody
    extend T::Sig

    def process(&blk)
    end
  end

  sig { params(blk: T.proc.bind(MiddlewareBody)).returns(MiddlewareSetupProc) }
  def self.middleware(&blk)
  end

  Thunk =
    middleware do |store|
      process do |action|
        case action
        when Proc
        end
      end
    end

  sig { params(blk: ReducerProc).returns(ReducerProc) }
  def self.reducer(&blk) = blk

  class Store
    extend T::Sig

    sig { returns(State) }
    attr_reader :state
    sig { returns(Async::Notification) }
    attr_reader :notification

    sig { params(initial_state: State, reducer: ReducerProc).void }
    def initialize(initial_state = {}, &reducer)
      @notification = T.let(Async::Notification.new, Async::Notification)
      @state = initial_state
      @reducer = reducer
    end

    def dispatch(action)
      @state = @reducer.call(@state, action)
      @notification.signal
    end
  end
end
