#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::UpdateIntervalTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class Counter < Mayu::Component::Base
    def initialize
      @count = 0
    end

    def increment
      @count += 1
      rerender!
    end

    def render
      H[:p, "count #{@count}"]
    end
  end

  def test_state_changes_during_the_pause_collapse_into_one_batch
    run_engine(H[:body, H[Counter]]) do |engine|
      instance = find_component(engine.root, Counter).instance_variable_get(:@instance)
      wait_until { instance.respond_to?(:rerender!) }
      engine.update_interval = 0.3

      instance.increment
      refute_nil(text_patch(engine, "count 1"))

      # The updater is pausing now, so these arrive together in the next pass.
      instance.increment
      Async::Task.current.sleep(0.02)
      instance.increment

      batch = Async::Task.current.with_timeout(1) { engine.dequeue_batch }
      contents = unwrap_commands(batch).grep(Mayu::Runtime::Commands::SetTextContent).map(&:content)
      assert_equal(["count 3"], contents)
    end
  end

  class Ticker < Mayu::Component::Base
    attr_reader :ticks

    def initialize
      @ticks = 0
    end

    def mount
      loop do
        sleep 0.01
        @ticks += 1
      end
    end

    def render
      H[:p, "ticker"]
    end
  end

  def test_a_mount_loop_ticks_at_the_update_interval_while_paused
    run_engine(H[:body, H[Ticker]]) do |engine|
      instance = find_component(engine.root, Ticker).instance_variable_get(:@instance)
      wait_until { instance.ticks > 0 }

      Async::Task.current.sleep(0.3)
      assert_operator(instance.ticks, :>=, 10, "expected fast ticks while visible")

      engine.update_interval = 0.2
      before = instance.ticks
      Async::Task.current.sleep(0.5)

      assert_operator(instance.ticks - before, :<=, 4, "expected slow ticks while paused")
    end
  end

  private

  def text_patch(engine, content)
    dequeue_until(engine) do |commands|
      commands.any? do |command|
        command.is_a?(Mayu::Runtime::Commands::SetTextContent) && command.content == content
      end
    end
  end
end
