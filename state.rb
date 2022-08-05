require "pry"

module State
  class Store
    attr_reader :state

    def initialize(initial_state, reducer:, middleware: [])
      @reducer = reducer
      @state = initial_state || {}

      dispatch = self.method(:dispatch_without_middleware)

      @middleware = middleware
        .map { _1.call(self) }
        .reverse
        .map.with_index { |m, i|
          fn = m.call(dispatch)
          new_dispatch = ->(action) { dispatch(action) }
          dispatch = new_dispatch
          fn
        }.last
    end

    def dispatch(action, *args, **kwargs)
      if action.is_a?(ActionCreator::Base)
        return dispatch(action.call(*args, **kwargs))
      end

      dispatch_without_middleware(@middleware.call(action))
    end

    private

    def dispatch_without_middleware(action)
      @state = @reducer.call(@state.dup, action)
    end
  end

  module ActionCreator
    class Base
      attr_reader :type

      def initialize(type)
        @type = type
      end

      def call(payload = nil)
        { type:, payload: }
      end

      def ===(other)
        if other.is_a?(Hash) && other[:type] == @type
          true
        else
          super
        end
      end
    end

    class StaticActionCreator < Base
    end

    class PreparedActionCreator < Base
      def initialize(type, &block)
        super(type)
        @prepare = block
      end

      def call(*args, **kwargs)
        { type: }.merge(@prepare.call(*args, **kwargs))
      end
    end

    class AsyncActionCreator < Base
      def call(ctx)
      end
    end

    def self.create(type, &block)
      if block_given?
        PreparedActionCreator.new(type, &block)
      else
        StaticActionCreator.new(type)
      end
    end

    # def self.async(type, &block)
    #   block.call(AsyncContext.)
    # end
  end
end

def combine_reducers(**reducers)
  ->(state, action) do
    reducers.reduce(state) do |new_state, (name, reducer)|
      new_state.merge(name => reducer.call(state[name], action))
    end
  end
end

INCREMENT = State::ActionCreator.create(:increment)
DECREMENT = State::ActionCreator.create(:decrement)
ADD_ITEM = State::ActionCreator.create(:add_item)
REMOVE_ITEM = State::ActionCreator.create(:remove_item)
THUNK = ->(dispatch) {
  dispatch.call(INCREMENT)
  sleep 1
  dispatch.call(INCREMENT)
  sleep 1
  dispatch.call(DECREMENT)
}

# State::ActionCreator.async(:foobar) do |ctx|
#   ctx.dispatch()
# end

count_reducer = ->(state, action) do
  state ||= { count: 0 }

  case action
  when INCREMENT
    state.merge(count: state[:count].succ)
  when DECREMENT
    state.merge(count: state[:count].pred)
  else
    state
  end
end

totals_reducer = ->(state, action) do
  state ||= 0

  case action
  in ADD_ITEM
    state += 1
  in REMOVE_ITEM
    state -= 1
  else
    state
  end
end

items_reducer = -> (state, action) do
  state ||= []

  case action
  in ADD_ITEM
    state + [action[:payload][:item]]
  in REMOVE_ITEM
    state - [action[:payload][:item]]
  else
    state
  end
end

thunk = ->store {
  p store: store
  ->continue {
    p continue: continue
    ->action {
      p action: action
      if action.is_a?(Proc)
        action.call(store.dispatch, store.get_state)
      else
        continue.call(action)
      end
    }
  }
}

@store = State::Store.new(
  { total: 0, items: [] },
  reducer: combine_reducers(
    count1: count_reducer,
    count2: count_reducer,
    items: items_reducer,
    totals: totals_reducer,
  ),
  middleware: [thunk]
)

@store.dispatch(ADD_ITEM, item: 'Apple')
@store.dispatch(ADD_ITEM, item: 'Banana')
@store.dispatch(REMOVE_ITEM, item: 'Apple')
@store.dispatch(ADD_ITEM, item: 'Papaya')
@store.dispatch(INCREMENT)

puts @store.state
@store.dispatch(THUNK)
puts @store.state
