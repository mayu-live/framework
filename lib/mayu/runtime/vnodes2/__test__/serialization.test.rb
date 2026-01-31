#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes2::SerializationTest < Minitest::Test
  include Mayu::Runtime::VNodes2::TestHelpers

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

  def test_engine_serialization_round_trip
    descriptor = H[:body, H[SerializeProbe]]

    with_modules_system(SerializeProbe) do
      engine =
        Mayu::Runtime::VNodes2::Engine.new(descriptor, metrics: NullMetrics.new)

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
      restored =
        Mayu::Runtime::VNodes2::Engine.restore(dumped, metrics: NullMetrics.new)

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
      engine =
        Mayu::Runtime::VNodes2::Engine.new(descriptor, metrics: NullMetrics.new)

      run_engine_instance(engine) do
        document = engine.root
        patcher = Mayu::Runtime::VNodes2::Patcher.new
        document.update(patcher, descriptor)

        wait_until { document.instance_variable_get(:@listeners).any? }
      end

      dumped = engine.dump!
      restored =
        Mayu::Runtime::VNodes2::Engine.restore(dumped, metrics: NullMetrics.new)

      listeners = restored.root.instance_variable_get(:@listeners)
      assert_equal(0, listeners.size)

      run_engine_instance(restored) do
        document = restored.root
        patcher = Mayu::Runtime::VNodes2::Patcher.new
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
end
