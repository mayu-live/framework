#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"
require_relative "../../../klenod"

require "fileutils"
require "tmpdir"

class Mayu::Runtime::VNodes::HotReloadTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  EVENTS = []

  class ChildProbe < Mayu::Component::Base
    def mount
      EVENTS << :child_mount
    end

    def unmount
      EVENTS << :child_unmount
    end

    def render
      H[:span, "child"]
    end
  end

  class BeforeProbe < Mayu::Component::Base
    attr_reader :count

    def initialize
      @count = 0
    end

    def mount
      EVENTS << :before_mount
    end

    def unmount
      EVENTS << :before_unmount
    end

    def increment
      @count += 1
      rerender!
    end

    def render
      H[
        :button,
        "before #{@count} #{@__props[:label]}",
        H[ChildProbe],
        onclick: H.callback(self, :increment)
      ]
    end
  end

  class AfterProbe < Mayu::Component::Base
    attr_reader :count, :added

    def initialize
      @count = 100
      @added = "default"
    end

    def mount
      EVENTS << :after_mount
    end

    def unmount
      EVENTS << :after_unmount
    end

    def increment
      @count += 10
      rerender!
    end

    def render
      H[
        :button,
        "after #{@count} #{@added} #{@__props[:label]}",
        H[ChildProbe],
        onclick: H.callback(self, :increment)
      ]
    end
  end

  class IncompatibleBeforeProbe < Mayu::Component::Base
    def initialize
      @count = 1
      @unserializable = $stdout
    end

    def render
      H[:p, "before incompatible #{@count}"]
    end
  end

  class IncompatibleAfterProbe < Mayu::Component::Base
    attr_reader :count

    def initialize
      @count = 100
    end

    def render
      H[:p, "after incompatible #{@count}"]
    end
  end

  class AsyncBeforeProbe < Mayu::Component::Base
    def mount
      EVENTS << :async_before_mount
      sleep
    ensure
      EVENTS << :async_before_stopped
    end

    def unmount
      EVENTS << :async_before_unmount
    end

    def render
      H[:p, "async before"]
    end
  end

  class AsyncAfterProbe < Mayu::Component::Base
    def mount
      EVENTS << :async_after_mount
    end

    def render
      H[:p, "async after"]
    end
  end

  ComponentResolver =
    Data.define(:families) do
      def dump_component_class(component)
        family = families[component]
        return unless family

        Mayu::Runtime::Marshalling::ComponentRef.new(
          "app:/components/#{family}.haml",
          "Default",
          nil
        )
      end
    end

  Provider =
    Data.define(:component_resolver) do
      def assets_for_module(_module_path, type:)
        raise "Expected CSS assets" unless type == :css

        []
      end
    end

  def setup
    EVENTS.clear
  end

  def test_refresh_replaces_the_class_while_preserving_state_and_vnodes
    engine = build_engine(BeforeProbe, label: "old")

    run_engine_instance(engine) do
      before_vnode = find_component(engine.root, BeforeProbe)
      before = before_vnode.instance_variable_get(:@instance)
      child_vnode = find_component(engine.root, ChildProbe)
      listener_id = listener_for(engine).id

      wait_until do
        EVENTS.include?(:before_mount) && EVENTS.include?(:child_mount)
      end
      before.increment
      wait_for_text_patch(engine, "before 1 old")

      engine.refresh(descriptor(AfterProbe, label: "new"))
      wait_for_text_patch(engine, "after 1 default new")

      after_vnode = find_component(engine.root, AfterProbe)
      after = after_vnode.instance_variable_get(:@instance)

      assert_same(before_vnode, after_vnode)
      refute_same(before, after)
      assert_same(child_vnode, find_component(engine.root, ChildProbe))
      assert_equal(1, after.count)
      assert_equal("default", after.added)
      assert_equal(listener_id, listener_for(engine).id)
      wait_until do
        EVENTS.include?(:before_unmount) && EVENTS.include?(:after_mount)
      end
      assert_equal(1, EVENTS.count(:child_mount))
      assert_equal(0, EVENTS.count(:child_unmount))

      engine.callback(listener_id, {})
      wait_for_text_patch(engine, "after 11 default new")
      assert_equal(11, after.count)
    end
  end

  def test_refreshes_classes_reloaded_by_klenod
    Dir.mktmpdir("mayu-component-hmr") do |root|
      app_dir = File.join(root, "app")
      FileUtils.mkdir_p(app_dir)
      component_path = File.join(app_dir, "counter.haml")
      File.write(component_path, component_source("before", increment: 1))

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      entry = provider.entry("counter.haml")
      before_class = provider.exports(entry)::Default
      engine =
        Mayu::Runtime::Engine.new(
          H[:body, H[before_class]],
          metrics: NullMetrics.new,
          module_provider: provider
        )

      run_engine_instance(engine) do
        before_vnode = find_component(engine.root, before_class)
        before = before_vnode.instance_variable_get(:@instance)
        wait_until { before.respond_to?(:rerender!) }

        before.increment
        wait_for_text_patch(engine, "before 1")

        File.write(component_path, component_source("after", increment: 10))
        result = provider.context.invalidate_paths([component_path])
        event =
          ::Klenod::Build::UpdateEvent.new(
            [component_path],
            [],
            1,
            result
          )
        update = provider.apply_update(event, entry:)
        assert(update.success?)

        after_class = provider.exports(entry)::Default
        refute_same(before_class, after_class)
        engine.refresh(H[:body, H[after_class]])
        wait_for_text_patch(engine, "after 1")

        after_vnode = find_component(engine.root, after_class)
        after = after_vnode.instance_variable_get(:@instance)
        assert_same(before_vnode, after_vnode)

        after.increment
        wait_for_text_patch(engine, "after 11")
      end
    end
  end

  def test_incompatible_state_resets_only_the_replaced_component
    engine =
      build_engine(
        IncompatibleBeforeProbe,
        label: nil,
        families: {
          IncompatibleBeforeProbe => "incompatible",
          IncompatibleAfterProbe => "incompatible"
        }
      )

    run_engine_instance(engine) do
      engine.refresh(H[:body, H[IncompatibleAfterProbe]])
      wait_for_text_patch(engine, "after incompatible 100")

      after =
        find_component(engine.root, IncompatibleAfterProbe)
          .instance_variable_get(:@instance)
      assert_equal(100, after.count)
    end
  end

  def test_refresh_cancels_old_mount_work_before_starting_the_replacement
    engine =
      build_engine(
        AsyncBeforeProbe,
        label: nil,
        families: {
          AsyncBeforeProbe => "async",
          AsyncAfterProbe => "async"
        }
      )

    run_engine_instance(engine) do
      wait_until { EVENTS.include?(:async_before_mount) }
      engine.refresh(H[:body, H[AsyncAfterProbe]])
      wait_for_text_patch(engine, "async after")
      wait_until do
        EVENTS.include?(:async_before_stopped) &&
          EVENTS.include?(:async_before_unmount) &&
          EVENTS.include?(:async_after_mount)
      end

      assert_operator(
        EVENTS.index(:async_before_stopped),
        :<,
        EVENTS.index(:async_after_mount)
      )
      assert_operator(
        EVENTS.index(:async_before_unmount),
        :<,
        EVENTS.index(:async_after_mount)
      )
    end
  end

  private

  def build_engine(
    component,
    label:,
    families: {
      BeforeProbe => "probe",
      AfterProbe => "probe"
    }
  )
    resolver =
      ComponentResolver.new(families)
    Mayu::Runtime::Engine.new(
      descriptor(component, label:),
      metrics: NullMetrics.new,
      module_provider: Provider.new(resolver)
    )
  end

  def descriptor(component, label:)
    H[:body, H[component, label:]]
  end

  def listener_for(engine)
    engine.root.instance_variable_get(:@listeners).values.fetch(0)
  end

  def wait_for_text_patch(engine, content)
    patches =
      dequeue_until(engine) do |batch|
        batch.any? do |patch|
          patch.is_a?(Mayu::Runtime::Patches::SetTextContent) &&
            patch.content == content
        end
      end
    refute_nil(patches, "Expected a SetTextContent patch for #{content.inspect}")
  end

  def component_source(label, increment:)
    <<~HAML
      :ruby
        def initialize
          @count = 0
        end

        def increment
          @count += #{increment}
          rerender!
        end

      %p #{label} \#{@count}
    HAML
  end
end
