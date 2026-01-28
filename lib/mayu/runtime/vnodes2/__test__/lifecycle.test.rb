#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes2::LifecycleTest < Minitest::Test
  include Mayu::Runtime::VNodes2::TestHelpers

  class MountProbe < Mayu::Component::Base
    attr_reader :mounted, :unmounted

    def mount
      @mounted = true
    end

    def unmount
      @unmounted = true
    end

    def render
      H[:div, "probe"]
    end
  end

  def test_component_start_stop_and_rerender
    descriptor = H[:body, H[MountProbe]]

    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)
    document = engine.root

    instance = nil

    run_engine(descriptor) do |engine|
      document = engine.root
      component = find_component(document, MountProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.mounted }

      assert(instance.mounted)

      instance.rerender!

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      assert_equal([], patches)
    end

    assert(instance.unmounted)
  end
end
