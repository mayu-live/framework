#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::SerializationTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class SerializeProbe < Mayu::Component::Base
    def self.module_path = "/tests/serialize"

    attr_reader :count, :mount_count, :unmount_count

    def initialize
      @count = 0
      @mount_count = 0
      @unmount_count = 0
    end

    def mount
      @mount_count += 1
    end

    def unmount
      @unmount_count += 1
    end

    def bump
      @count += 1
      rerender!
    end

    def render
      H[:p, @count.to_s]
    end
  end

  class CallbackProbe < Mayu::Component::Base
    def initialize
      @count = 0
    end

    def render
      H[:button, "Click #{@count}", onclick: H.callback(self, :handle_click)]
    end

    def handle_click
      @count += 1
      rerender!
    end
  end

  class RenamedSourceComponent < Mayu::Component::Base
    def self.module_path = "/tests/renamed_component"

    attr_reader :count

    def initialize
      @count = 0
    end

    def bump
      @count += 1
      rerender!
    end

    def render
      H[:p, "before #{@count}"]
    end
  end

  class RenamedTargetComponent < Mayu::Component::Base
    def self.module_path = "/tests/renamed_component"

    attr_reader :count

    def initialize
      @count = 0
    end

    def render
      H[:p, "after #{@count}"]
    end
  end

  def test_engine_serialization_round_trip
    descriptor = H[:body, H[SerializeProbe]]

    with_modules_system(SerializeProbe) do
      engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

      run_engine_instance(engine) do
        component = find_component(engine.root, SerializeProbe)
        instance = component.instance_variable_get(:@instance)

        wait_until { instance.respond_to?(:rerender!) }

        instance.bump
        batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
        unwrap_patches(batch)
        instance.bump
        batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
        unwrap_patches(batch)

        assert_equal(2, instance.count)
        assert_equal(1, instance.mount_count)
        assert_equal(0, instance.unmount_count)
      end

      dumped = engine.dump!
      restored = Mayu::Runtime::Engine.restore(dumped, metrics: NullMetrics.new)

      html = render_html(restored.root)
      assert_match("<p>2</p>", html)

      run_engine_instance(restored) do
        component = find_component(restored.root, SerializeProbe)
        instance = component.instance_variable_get(:@instance)

        wait_until { instance.respond_to?(:rerender!) }

        assert_equal(2, instance.count)
        assert_equal(2, instance.mount_count)
        assert_equal(1, instance.unmount_count)
      end

      component = find_component(restored.root, SerializeProbe)
      instance = component.instance_variable_get(:@instance)
      assert_equal(2, instance.unmount_count)
    end
  end

  def test_serialization_restores_callback_listeners
    descriptor = H[:body, H[CallbackProbe]]

    with_modules_system(CallbackProbe) do
      engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

      run_engine_instance(engine) do
        document = engine.root
        patcher = Mayu::Runtime::VNodes::Patcher.new
        document.update(patcher, descriptor)

        wait_until { document.instance_variable_get(:@listeners).any? }
      end

      dumped = engine.dump!
      restored = Mayu::Runtime::Engine.restore(dumped, metrics: NullMetrics.new)

      listeners = restored.root.instance_variable_get(:@listeners)
      assert(listeners.any?)

      run_engine_instance(restored) do
        document = restored.root
        patcher = Mayu::Runtime::VNodes::Patcher.new
        document.update(patcher, descriptor)

        component = find_component(document, CallbackProbe)
        instance = component.instance_variable_get(:@instance)

        wait_until do
          document.instance_variable_get(:@listeners).any? &&
            instance.singleton_methods.include?(:rerender!)
        end

        listener = document.instance_variable_get(:@listeners).values.first
        refute_nil(listener)

        restored.callback(listener.id, {})
        batch =
          Async::Task.current.with_timeout(0.5) { restored.dequeue_patches }
        patches = unwrap_patches(batch)

        set_text =
          patches.find do |patch|
            patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
          end

        refute_nil(set_text)
        assert_equal("Click 1", set_text.content)
      end
    end
  end

  def test_restore_resolves_component_from_filename_when_export_name_changes
    descriptor = H[:body, H[RenamedSourceComponent]]
    module_path = RenamedSourceComponent.module_path

    with_dynamic_module_system(module_path) do |mods|
      mods[module_path] = build_mod(RenamedSourceComponent)

      engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

      run_engine_instance(engine) do
        component = find_component(engine.root, RenamedSourceComponent)
        instance = component.instance_variable_get(:@instance)

        wait_until { instance.respond_to?(:rerender!) }

        instance.instance_variable_set(:@count, 2)

        assert_equal(2, instance.count)
      end

      dumped = engine.dump!
      mods[module_path] = build_mod(RenamedTargetComponent, name_const: false)

      restored = Mayu::Runtime::Engine.restore(dumped, metrics: NullMetrics.new)
      component = find_component(restored.root, RenamedTargetComponent)
      refute_nil(component)

      instance = component.instance_variable_get(:@instance)
      assert_instance_of(RenamedTargetComponent, instance)
      assert_equal(2, instance.count)
    end
  end

  private

  def build_mod(component_class, name_const: true)
    mod = Module.new
    exports = Module.new

    if name_const
      exports.const_set(component_class.name.split("::").last, component_class)
    end
    exports.const_set(:Default, component_class)

    mod.const_set(:Exports, exports)
    mod.define_singleton_method(:assets) { [] }
    mod.define_singleton_method(:dependencies) { [] }
    mod
  end

  def with_dynamic_module_system(module_path)
    mods = {}
    system =
      Data
        .define(:mods) do
          def get_mod(path)
            mods[path]
          end

          def import(path, _source = "/")
            mod = mods[path]
            raise "Missing module #{path.inspect}" unless mod
            mod::Exports::Default
          end
        end
        .new(mods)

    key = Mayu::Modules::System::CURRENT_KEY
    previous = Thread.current.thread_variable_get(key)
    Thread.current.thread_variable_set(key, system)

    yield mods
  ensure
    Thread.current.thread_variable_set(key, previous)
  end
end
