# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "vdom/descriptor"
require_relative "state"

class TestState < Minitest::Test
  class MyComponent < Mayu::Component::Base
  end

  State = Mayu::State

  INCREMENT = State::ActionCreator.create(:increment)
  DECREMENT = State::ActionCreator.create(:decrement)
  ADD_ITEM = State::ActionCreator.create(:add_item)
  REMOVE_ITEM = State::ActionCreator.create(:remove_item)
  THUNK =
    State::ActionCreator.async(:hello) do |store|
      store.dispatch(INCREMENT)
      sleep 1
      store.dispatch(INCREMENT)
      sleep 1
      store.dispatch(DECREMENT)
    end

  def test_initialize_descriptor
    Sync do
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

      items_reducer = ->(state, action) do
        state ||= []
        p action

        case action
        in ADD_ITEM
          state + [action[:item]]
        in REMOVE_ITEM
          state - [action[:item]]
        else
          state
        end
      end

      @store =
        State::Store.new(
          { total: 0, items: [] },
          reducers: {
            count1: count_reducer,
            count2: count_reducer,
            items: items_reducer,
            totals: totals_reducer
          }
        )

      @store.dispatch(ADD_ITEM, item: "Apple")
      @store.dispatch(ADD_ITEM, item: "Banana")
      @store.dispatch(REMOVE_ITEM, item: "Apple")
      @store.dispatch(ADD_ITEM, item: "Papaya")
      @store.dispatch(INCREMENT)

      puts @store.state
      @store.dispatch(THUNK)
      sleep 0.1
      @store.dispatch(THUNK)
      puts "hello"
      puts @store.state
    end
  end
end
