#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::ErrorBoundaryTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class ErrorChild < Mayu::Component::Base
    def render
      raise "boom" if @__props[:should_fail]
      H[:span, "ok"]
    end
  end

  class ErrorBoundaryProbe < Mayu::Component::Base
    def initialize
      @should_fail = false
      @handled = false
    end

    def handle_error(_error)
      @handled = true
      true
    end

    def trigger_error
      @should_fail = true
      rerender!
    end

    def render
      return H[:div, "Error handled"] if @handled
      H[ErrorChild, should_fail: @should_fail]
    end
  end

  class RenderErrorProbe < Mayu::Component::Base
    def self.module_path = "/tests/render_error"

    def initialize
      @should_fail = false
    end

    def trigger_error
      @should_fail = true
      rerender!
    end

    def render
      raise "boom" if @should_fail
      H[:div, "ok"]
    end
  end

  def test_error_boundary_rerenders_on_error
    descriptor = H[:body, H[ErrorBoundaryProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ErrorBoundaryProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.trigger_error

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      refute_nil(patches)

      html = render_html(engine.root)
      assert_match("<div>Error handled</div>", html)
    end
  end

  def test_error_boundary_render_html
    descriptor = H[:body, H[ErrorBoundaryProbe]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

    component = find_component(engine.root, ErrorBoundaryProbe)
    instance = component.instance_variable_get(:@instance)
    instance.instance_variable_set(:@should_fail, true)

    html = render_html(engine.root)
    assert_match("<div>Error handled</div>", html)
  end

  def test_unhandled_render_error_emits_patch
    descriptor = H[:body, H[RenderErrorProbe]]

    with_modules_system_with_source_map(RenderErrorProbe) do
      run_engine(descriptor) do |engine|
        component = find_component(engine.root, RenderErrorProbe)
        instance = component.instance_variable_get(:@instance)

        wait_until { instance.respond_to?(:rerender!) }
        instance.trigger_error

        patches =
          dequeue_until(engine) do |batch|
            batch.any? do |patch|
              patch.is_a?(Mayu::Runtime::Patches::RenderError)
            end
          end

        refute_nil(patches)

        render_error =
          patches.find do |patch|
            patch.is_a?(Mayu::Runtime::Patches::RenderError)
          end

        assert_equal("/tests/render_error", render_error.file)
        assert_equal("RuntimeError", render_error.type)
        assert_equal("boom", render_error.message)
        refute_nil(render_error.source)
      end
    end
  end

  def test_render_error_tree_path_order
    descriptor = H[:body, H[RenderErrorProbe]]

    with_modules_system_with_source_map(RenderErrorProbe) do
      run_engine(descriptor) do |engine|
        component = find_component(engine.root, RenderErrorProbe)
        instance = component.instance_variable_get(:@instance)

        wait_until { instance.respond_to?(:rerender!) }
        instance.trigger_error

        patches =
          dequeue_until(engine) do |batch|
            batch.any? do |patch|
              patch.is_a?(Mayu::Runtime::Patches::RenderError)
            end
          end

        refute_nil(patches)

        render_error =
          patches.find do |patch|
            patch.is_a?(Mayu::Runtime::Patches::RenderError)
          end

        tree_path = render_error.tree_path
        assert_equal({ name: "#document" }, tree_path.first)
        assert_equal(
          { name: "RenderErrorProbe", path: "/tests/render_error" },
          tree_path.last
        )
        assert(tree_path.any? { |node| node[:name] == "body" })
        assert(tree_path.any? { |node| node[:name] == "html" })
      end
    end
  end

  private

  def with_modules_system_with_source_map(component_class)
    mod = Module.new
    exports = Module.new
    exports.const_set(component_class.name.split("::").last, component_class)
    mod.const_set(:Exports, exports)
    mod.define_singleton_method(:assets) { [] }
    mod.define_singleton_method(:dependencies) { [] }
    mod.define_singleton_method(:source_map) do
      Data.define(:input).new("source")
    end

    system =
      Data
        .define(:mod) do
          def get_mod(_path)
            mod
          end

          def format_exception(error)
            "#{error.class}: #{error.message}"
          end
        end
        .new(mod)

    key = Mayu::Modules::System::CURRENT_KEY
    previous = Thread.current.thread_variable_get(key)
    Thread.current.thread_variable_set(key, system)
    yield
  ensure
    Thread.current.thread_variable_set(key, previous)
  end
end
