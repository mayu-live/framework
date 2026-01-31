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

  class DynamicMountProbe < Mayu::Component::Base
    attr_reader :mounted

    def mount
      @mounted = true
    end

    def render
      H[:div, "dynamic"]
    end
  end

  class ParentToggleProbe < Mayu::Component::Base
    def initialize
      @show = false
    end

    def show!
      @show = true
      rerender!
    end

    def render
      @show ? H[:section, H[DynamicMountProbe]] : H[:section]
    end
  end

  class UnmountProbe < Mayu::Component::Base
    attr_reader :unmounted

    def unmount
      @unmounted = true
    end

    def render
      H[:div, "gone"]
    end
  end

  class ParentRemoveProbe < Mayu::Component::Base
    def initialize
      @show = true
    end

    def hide!
      @show = false
      rerender!
    end

    def render
      @show ? H[:section, H[UnmountProbe]] : H[:section]
    end
  end

  class GrandchildUnmountProbe < Mayu::Component::Base
    attr_reader :unmounted

    def unmount
      @unmounted = true
    end

    def render
      H[:span, "grandchild"]
    end
  end

  class NestedRemoveProbe < Mayu::Component::Base
    def render
      H[:div, H[GrandchildUnmountProbe]]
    end
  end

  class ParentNestedRemoveProbe < Mayu::Component::Base
    def initialize
      @show = true
    end

    def hide!
      @show = false
      rerender!
    end

    def render
      @show ? H[:section, H[NestedRemoveProbe]] : H[:section]
    end
  end

  class DoubleRerenderProbe < Mayu::Component::Base
    attr_reader :renders

    def initialize
      @renders = 0
      @a = 0
      @b = 0
    end

    def mount
      @a = 1
      rerender!
      @b = 2
      rerender!
    end

    def render
      @renders += 1
      H[:div, "#{@a}-#{@b}"]
    end
  end

  class DoubleRerenderCallbackProbe < Mayu::Component::Base
    attr_reader :renders

    def initialize
      @renders = 0
      @a = 0
      @b = 0
    end

    def trigger
      @a = 3
      rerender!
      @b = 4
      rerender!
    end

    def render
      @renders += 1
      H[:button, "#{@a}-#{@b}", onclick: H.callback(self, :trigger)]
    end
  end

  def test_component_start_stop_and_rerender
    descriptor = H[:body, H[MountProbe]]

    engine =
      Mayu::Runtime::VNodes2::Engine.new(descriptor, metrics: NullMetrics.new)
    document = engine.root

    instance = nil

    run_engine(descriptor) do |engine|
      document = engine.root
      component = find_component(document, MountProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.mounted }

      assert(instance.mounted)

      instance.rerender!

      assert_no_patches(engine)
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
      assert_no_patches(engine)

      wait_until { instance.listener_task }
      refute_nil(instance.listener_task)
      refute_equal(task, instance.listener_task)
    end
  end

  def test_new_component_started_after_insert
    descriptor = H[:body, H[ParentToggleProbe]]

    run_engine(descriptor) do |engine|
      parent = find_component(engine.root, ParentToggleProbe)
      parent_instance = parent.instance_variable_get(:@instance)

      wait_until { parent_instance.instance_variable_get(:@__vnode_task) }
      parent_instance.show!

      dynamic = nil
      wait_until do
        dynamic = find_component(engine.root, DynamicMountProbe)
        dynamic
      end

      dynamic_instance = dynamic.instance_variable_get(:@instance)
      wait_until { dynamic_instance.mounted }

      assert(dynamic_instance.mounted)
    end
  end

  def test_component_unmounted_after_remove
    descriptor = H[:body, H[ParentRemoveProbe]]

    run_engine(descriptor) do |engine|
      parent = find_component(engine.root, ParentRemoveProbe)
      parent_instance = parent.instance_variable_get(:@instance)

      wait_until { parent_instance.instance_variable_get(:@__vnode_task) }

      child = find_component(engine.root, UnmountProbe)
      child_instance = child.instance_variable_get(:@instance)

      parent_instance.hide!

      wait_until { child_instance.unmounted }
      assert(child_instance.unmounted)
    end
  end

  def test_nested_children_unmounted_after_remove
    descriptor = H[:body, H[ParentNestedRemoveProbe]]

    run_engine(descriptor) do |engine|
      parent = find_component(engine.root, ParentNestedRemoveProbe)
      parent_instance = parent.instance_variable_get(:@instance)

      wait_until { parent_instance.instance_variable_get(:@__vnode_task) }

      grandchild = find_component(engine.root, GrandchildUnmountProbe)
      grandchild_instance = grandchild.instance_variable_get(:@instance)
      span = find_element(engine.root, :span)
      refute_nil(span)

      parent_instance.hide!

      wait_until { grandchild_instance.unmounted }
      assert(grandchild_instance.unmounted)
      wait_until { grandchild.removed? && span.removed? }
      assert(grandchild.removed?)
      assert(span.removed?)
    end
  end

  def test_multiple_rerender_calls_coalesce_in_same_tick
    descriptor = H[:body, H[DoubleRerenderProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, DoubleRerenderProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.renders >= 2 }
      assert_equal(2, instance.renders)

      Async::Task.current.sleep(0.05)
      assert_equal(2, instance.renders)
    end
  end

  def test_multiple_rerender_calls_in_callback_coalesce
    descriptor = H[:body, H[DoubleRerenderCallbackProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, DoubleRerenderCallbackProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.renders >= 1 }
      assert_equal(1, instance.renders)

      document = engine.root
      patcher = Mayu::Runtime::VNodes2::Patcher.new
      document.update(patcher, descriptor)

      wait_until { document.instance_variable_get(:@listeners).any? }
      listener = document.instance_variable_get(:@listeners).values.first
      refute_nil(listener)

      engine.callback(listener.id, {})

      wait_until { instance.renders >= 2 }
      assert_equal(2, instance.renders)

      Async::Task.current.sleep(0.05)
      assert_equal(2, instance.renders)
    end
  end
end
