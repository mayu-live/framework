# frozen_string_literal: true

require "minitest/autorun"

require_relative "state"

class Mayu::Component::StateTest < Minitest::Test
  class Owner
    attr_reader :updates

    def initialize
      @updates = []
    end

    private

    def update!(value)
      @updates << value
    end
  end

  def test_writes_store_values_and_schedule_an_owner_update
    owner = Owner.new
    state = Mayu::Component::State.new(owner)

    assert_equal("value", state[:name] = "value")
    assert_equal("value", state[:name])
    assert_equal(["value"], owner.updates)
  end

  def test_marshal_round_trip_drops_and_can_rebind_the_owner
    owner = Owner.new
    state = Mayu::Component::State.new(owner)
    state[:count] = 1

    restored = Marshal.load(Marshal.dump(state))
    restored[:count] = 2
    assert_equal([1], owner.updates)

    restored.bind(owner)
    restored[:count] = 3
    assert_equal([1, 3], owner.updates)
  end
end
