#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::DidUpdateTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class Probe < Mayu::Component::Base
    attr_reader :updates, :loaded

    def initialize
      @updates = []
      @loaded = nil
    end

    def should_update?(next_props)
      !next_props[:skip]
    end

    def did_update(prev_props)
      @updates << [prev_props[:id], @__props[:id], Async::Task.current.parent]
      # The hook runs outside a render, so it can update state.
      @loaded = @__props[:id]
      rerender!
    end

    def render
      H[:div, "#{@__props[:id]}:#{@loaded}"]
    end
  end

  class Parent < Mayu::Component::Base
    def initialize
      @id = 1
      @skip = false
    end

    def show(id, skip: false)
      @id = id
      @skip = skip
      rerender!
    end

    def render
      H[:section, H[Probe, id: @id, skip: @skip]]
    end
  end

  def test_runs_after_a_prop_update_with_the_previous_props
    descriptor = H[:body, H[Parent]]

    run_engine(descriptor) do |engine|
      parent = find_component(engine.root, Parent).instance_variable_get(:@instance)
      probe_node = find_component(engine.root, Probe)
      probe = probe_node.instance_variable_get(:@instance)
      wait_until { parent.respond_to?(:rerender!) }

      parent.show(2)
      wait_until { probe.updates.size == 1 }

      prev_id, next_id, parent_task = probe.updates.first
      assert_equal(1, prev_id)
      assert_equal(2, next_id)
      assert_equal(
        probe_node.instance_variable_get(:@task),
        parent_task,
        "did_update runs in a task under the component task"
      )

      wait_until { render_html(engine.root).include?("2:2") }
    end
  end

  def test_skipped_renders_and_local_updates_do_not_run_the_hook
    descriptor = H[:body, H[Parent]]

    run_engine(descriptor) do |engine|
      parent = find_component(engine.root, Parent).instance_variable_get(:@instance)
      probe = find_component(engine.root, Probe).instance_variable_get(:@instance)
      wait_until { probe.respond_to?(:rerender!) }

      parent.show(2, skip: true)
      probe.rerender!
      wait_until { render_html(engine.root).include?("2:") }
      Async::Task.current.sleep(0.05)

      assert_empty(probe.updates)
    end
  end
end
