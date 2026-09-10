#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::ViewTransitionsTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class ViewTransitionChildProbe < Mayu::Component::Base
    def render
      H[:span, @__props[:value].to_s]
    end
  end

  class ViewTransitionProbe < Mayu::Component::Base
    def initialize
      @value = 0
    end

    def increment
      view_transition do
        @value += 1
        rerender!
      end
    end

    def render
      H[:div, H[ViewTransitionChildProbe, value: @value]]
    end
  end

  def test_view_transition_wraps_patches
    descriptor = H[:body, H[ViewTransitionProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ViewTransitionProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.increment

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      assert_kind_of(Mayu::Runtime::Batch, batch)
      assert_equal(1, batch.commands.length)
      assert_kind_of(
        Mayu::Runtime::Commands::ViewTransition,
        batch.commands.first
      )

      inner = unwrap_commands(batch)
      set_text =
        inner.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("1", set_text.content)
    end
  end

  def test_view_transition_not_used_for_regular_rerender
    descriptor = H[:body, H[ViewTransitionProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ViewTransitionProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.instance_variable_set(:@value, 1)
      instance.rerender!

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      patches = unwrap_commands(batch)

      refute_empty(patches)
      assert_kind_of(Mayu::Runtime::Batch, batch)
      refute(batch.commands.any? do |command|
        command.is_a?(Mayu::Runtime::Commands::ViewTransition)
      end)
    end
  end
end
