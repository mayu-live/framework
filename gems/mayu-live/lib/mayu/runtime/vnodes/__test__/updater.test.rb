#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::UpdaterTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  Commands = Mayu::Runtime::Commands

  class Fast < Mayu::Component::Base
    def initialize
      @count = 0
    end

    def bump
      @count += 1
      rerender!
    end

    def render
      H[:p, "Fast: #{@count}"]
    end
  end

  # Waits while it renders again, as a render that reads from a database
  # would.
  class Slow < Fast
    def render
      sleep(0.05) if @count > 0
      H[:p, "Slow: #{@count}"]
    end
  end

  def instance(engine, klass)
    component = find_component(engine.root, klass)
    instance = component.instance_variable_get(:@instance)
    wait_until { instance.respond_to?(:rerender!) }
    instance
  end

  # The pass has already changed the tree for the first component when the
  # second one makes it wait. Dropping it there would leave the tree ahead
  # of a browser that reconnects and is only sent what was queued.
  def test_a_pass_that_is_stopped_midway_still_queues_its_commands
    engine =
      Mayu::Runtime::Engine.new(
        H[:body, H[Fast], H[Slow]],
        metrics: NullMetrics.new
      )

    Async do |task|
      engine.start
      instance(engine, Fast).bump
      instance(engine, Slow).bump
      task.sleep(0.01)

      engine.stop

      assert_equal(
        [Commands::SetTextContent, Commands::SetTextContent],
        engine.take_queued_batches.flat_map(&:commands).map(&:class)
      )
      assert_includes(engine.resync_commands.first.html, "<p>Slow: 1</p>")
    end.wait
  end
end
