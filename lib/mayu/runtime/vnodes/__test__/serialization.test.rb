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

  ComponentResolver =
    Data.define(:source_component, :target_component) do
      def dump_component_class(component)
        return unless component == source_component

        Mayu::Runtime::Marshalling::ComponentRef.new(
          "app:/tests/renamed_component.haml",
          "RenamedSourceComponent",
          nil
        )
      end

      def resolve_component_ref(reference)
        return unless reference.filename == "app:/tests/renamed_component.haml"

        target_component
      end
    end

  Provider =
    Data.define(:component_resolver) do
      def assets_for_module(_module_path, type:)
        raise "Expected CSS assets" unless type == :css

        []
      end
    end

  StaticComponentResolver =
    Data.define(:component_class) do
      def dump_component_class(component)
        return unless component == component_class

        Mayu::Runtime::Marshalling::ComponentRef.new(
          "app:/tests/#{component.name.split("::").last}.haml",
          component.name.split("::").last,
          nil
        )
      end

      def resolve_component_ref(reference)
        unless reference.class_name == component_class.name.split("::").last
          return
        end

        component_class
      end
    end

  def test_engine_serialization_round_trip
    descriptor = H[:body, H[SerializeProbe]]

    provider = Provider.new(StaticComponentResolver.new(SerializeProbe))
    engine =
      Mayu::Runtime::Engine.new(
        descriptor,
        metrics: NullMetrics.new,
        module_provider: provider
      )

    run_engine_instance(engine) do
      component = find_component(engine.root, SerializeProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.bump
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      unwrap_commands(batch)
      instance.bump
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      unwrap_commands(batch)

      assert_equal(2, instance.count)
      assert_equal(1, instance.mount_count)
      assert_equal(0, instance.unmount_count)
    end

    dumped = engine.dump!
    restored =
      Mayu::Runtime::Engine.restore(
        dumped,
        metrics: NullMetrics.new,
        module_provider: provider
      )

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

  def test_serialization_restores_callback_listeners
    descriptor = H[:body, H[CallbackProbe]]

    provider = Provider.new(StaticComponentResolver.new(CallbackProbe))
    engine =
      Mayu::Runtime::Engine.new(
        descriptor,
        metrics: NullMetrics.new,
        module_provider: provider
      )

    run_engine_instance(engine) do
      document = engine.root
      collector = Mayu::Runtime::VNodes::CommandCollector.new
      document.update(collector, descriptor)

      wait_until { document.instance_variable_get(:@listeners).any? }
    end

    dumped = engine.dump!
    restored =
      Mayu::Runtime::Engine.restore(
        dumped,
        metrics: NullMetrics.new,
        module_provider: provider
      )

    listeners = restored.root.instance_variable_get(:@listeners)
    assert(listeners.any?)

    run_engine_instance(restored) do
      document = restored.root
      collector = Mayu::Runtime::VNodes::CommandCollector.new
      document.update(collector, descriptor)

      component = find_component(document, CallbackProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until do
        document.instance_variable_get(:@listeners).any? &&
          instance.singleton_methods.include?(:rerender!)
      end

      listener = document.instance_variable_get(:@listeners).values.first
      refute_nil(listener)

      restored.callback(listener.id, {})
      batch = Async::Task.current.with_timeout(0.5) { restored.dequeue_batch }
      patches = unwrap_commands(batch)

      set_text =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("Click 1", set_text.content)
    end
  end

  def test_restore_uses_the_module_provider_component_resolver
    provider =
      Provider.new(
        ComponentResolver.new(RenamedSourceComponent, RenamedTargetComponent)
      )
    descriptor = H[:body, H[RenamedSourceComponent]]
    engine =
      Mayu::Runtime::Engine.new(
        descriptor,
        metrics: NullMetrics.new,
        module_provider: provider
      )

    dumped = engine.dump!
    restored =
      Mayu::Runtime::Engine.restore(
        dumped,
        metrics: NullMetrics.new,
        module_provider: provider
      )

    assert_match("<p>after 0</p>", render_html(restored.root))
    assert_equal(provider, restored.module_provider)
  end
end
