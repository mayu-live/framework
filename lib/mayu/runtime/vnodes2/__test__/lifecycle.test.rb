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

  class TaskProbe < Mayu::Component::Base
    def initialize
      @mount_task = nil
      @listener_task = nil
    end

    def mount
      @mount_task = Async::Task.current
    end

    def handle_click
      @listener_task = Async::Task.current
      rerender!
    end

    def render
      H[:button, "Click", onclick: H.callback(self, :handle_click)]
    end

    attr_reader :mount_task, :listener_task
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

  def test_component_task_and_listener_task
    descriptor = H[:body, H[TaskProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, TaskProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      task = instance.instance_variable_get(:@__vnode_task)
      refute_nil(task)

      wait_until { instance.mount_task }
      refute_nil(instance.mount_task)
      refute_equal(task, instance.mount_task)

      document = engine.root
      patcher = Mayu::Runtime::VNodes2::Patcher.new
      document.update(patcher, descriptor)

      wait_until { document.instance_variable_get(:@listeners).any? }
      listener = document.instance_variable_get(:@listeners).values.first
      refute_nil(listener)

      engine.callback(listener.id, {})

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      refute_nil(patches)

      wait_until { instance.listener_task }
      refute_nil(instance.listener_task)
      refute_equal(task, instance.listener_task)
    end
  end
end
