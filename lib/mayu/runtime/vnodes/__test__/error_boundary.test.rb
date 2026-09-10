#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require "msgpack"
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

  class RewritingProvider
    attr_reader :rewritten_error

    def rewrite_exception(error)
      @rewritten_error = error
      error.set_backtrace(["app:/broken.haml:7"])
    end

    def format_exception(error, source_path:)
      "#{source_path}: #{error.class}: #{error.message}"
    end

    def assets_for_module(_module_path, type:)
      raise "Unexpected asset type #{type}" unless type == :css

      []
    end
  end

  def test_error_boundary_rerenders_on_error
    descriptor = H[:body, H[ErrorBoundaryProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ErrorBoundaryProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.trigger_error

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

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

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, RenderErrorProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }
      instance.trigger_error

      patches =
        dequeue_until(engine) do |batch|
          batch.any? do |patch|
            patch.is_a?(Mayu::Runtime::Commands::RenderError)
          end
        end

      refute_nil(patches)

      render_error =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::RenderError)
        end

      assert_equal("/tests/render_error", render_error.file)
      assert_equal("RuntimeError", render_error.type)
      assert_equal("boom", render_error.message)
      assert_nil(render_error.source)
    end
  end

  def test_unhandled_render_error_uses_an_injected_module_provider
    descriptor = H[:body, H[RenderErrorProbe]]
    provider =
      Data
        .define do
          def format_exception(error, source_path:)
            "#{source_path}: #{error.class}: #{error.message}"
          end

          def assets_for_module(_module_path, type:)
            raise "Unexpected asset type #{type}" unless type == :css

            []
          end
        end
        .new

    run_engine_with_provider(descriptor, provider) do |engine|
      component = find_component(engine.root, RenderErrorProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }
      instance.trigger_error

      patches =
        dequeue_until(engine) do |batch|
          batch.any? { it.is_a?(Mayu::Runtime::Commands::RenderError) }
        end
      render_error =
        patches.find { it.is_a?(Mayu::Runtime::Commands::RenderError) }

      assert_equal("/tests/render_error", render_error.file)
      assert_nil(render_error.source)
    end
  end

  def test_unhandled_render_error_rewrites_the_client_patch_backtrace
    descriptor = H[:body, H[RenderErrorProbe]]
    provider = RewritingProvider.new

    run_engine_with_provider(descriptor, provider) do |engine|
      component = find_component(engine.root, RenderErrorProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }
      instance.trigger_error

      patches =
        dequeue_until(engine) do |batch|
          batch.any? { it.is_a?(Mayu::Runtime::Commands::RenderError) }
        end
      render_error =
        patches.find { it.is_a?(Mayu::Runtime::Commands::RenderError) }

      refute_nil(provider.rewritten_error)
      assert_equal(["app:/broken.haml:7"], render_error.backtrace)
    end
  end

  def test_render_error_tree_path_order
    descriptor = H[:body, H[RenderErrorProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, RenderErrorProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }
      instance.trigger_error

      patches =
        dequeue_until(engine) do |batch|
          batch.any? do |patch|
            patch.is_a?(Mayu::Runtime::Commands::RenderError)
          end
        end

      refute_nil(patches)

      render_error =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::RenderError)
        end

      tree_path = render_error.tree_path
      assert_equal({name: "#document"}, tree_path.first)
      assert_equal(
        {name: "RenderErrorProbe", path: "/tests/render_error"},
        tree_path.last
      )
      assert(tree_path.any? { |node| node[:name] == "body" })
      assert(tree_path.any? { |node| node[:name] == "html" })
    end
  end

  def test_render_error_serializes_binary_encoded_text_as_utf8
    patch =
      Mayu::Runtime::Commands::RenderError[
        "app:/broken.haml".b,
        "SyntaxError".b,
        "unexpected token".b,
        ["app:/broken.haml:2".b],
        "%p= )\n".b,
        [{name: "CodeReload".b, path: "app:/broken.haml".b}]
      ]

    serialized = MessagePack.unpack(MessagePack.pack(patch))

    assert_equal("RenderError", serialized[0])
    assert_equal("app:/broken.haml", serialized[1])
    assert_equal("SyntaxError", serialized[2])
    assert_equal("unexpected token", serialized[3])
    assert_equal(["app:/broken.haml:2"], serialized[4])
    assert_equal("%p= )\n", serialized[5])
    assert_equal({"name" => "CodeReload", "path" => "app:/broken.haml"}, serialized[6][0])
    serialized.flatten.each do |value|
      assert_equal(Encoding::UTF_8, value.encoding) if value.is_a?(String)
    end
    serialized[6][0].each_value do |value|
      assert_equal(Encoding::UTF_8, value.encoding)
    end
  end

  private

  def run_engine_with_provider(descriptor, provider)
    engine =
      Mayu::Runtime::Engine.new(
        descriptor,
        metrics: NullMetrics.new,
        module_provider: provider
      )

    Async do
      engine.start
      yield engine
    ensure
      engine.stop
    end.wait
  end
end
