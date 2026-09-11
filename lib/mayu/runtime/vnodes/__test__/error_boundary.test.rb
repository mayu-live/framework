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
      @text = "ok"
    end

    def trigger_error
      @should_fail = true
      rerender!
    end

    def recover
      @should_fail = false
      @text = "recovered"
      rerender!
    end

    def render
      raise "boom" if @should_fail
      H[:div, @text]
    end
  end

  class DirectErrorChild < Mayu::Component::Base
    class << self
      attr_accessor :instance
    end

    def initialize
      self.class.instance = self
      @should_fail = false
    end

    def trigger_error
      @should_fail = true
      rerender!
    end

    def render
      raise "direct child failed" if @should_fail
      H[:span, "child"]
    end
  end

  class DirectErrorBoundary < Mayu::Component::Base
    def initialize
      @handled = false
    end

    def handle_error(error)
      @handled = error.message
      true
    end

    def render
      return H[:div, "Handled: #{@handled}"] if @handled
      H[DirectErrorChild]
    end
  end

  class SelfFailingBoundary < Mayu::Component::Base
    class << self
      attr_accessor :instance
    end

    attr_reader :handled

    def initialize
      self.class.instance = self
      @should_fail = false
      @handled = 0
    end

    def handle_error(_error)
      @handled += 1
      true
    end

    def trigger_error
      @should_fail = true
      rerender!
    end

    def render
      raise "self failed" if @should_fail
      H[:div, "ok"]
    end
  end

  class FailingFallbackBoundary < Mayu::Component::Base
    def initialize
      @handled = false
    end

    def handle_error(_error)
      @handled = true
      true
    end

    def render
      raise "fallback failed" if @handled
      H[ErrorChild, should_fail: @__props[:should_fail]]
    end
  end

  class ChildFailingFallbackBoundary < Mayu::Component::Base
    def initialize
      @handled = false
    end

    def handle_error(_error)
      @handled = true
      true
    end

    def render
      H[
        ErrorChild,
        should_fail: @handled || @__props[:should_fail]
      ]
    end
  end

  class DecliningBoundary < Mayu::Component::Base
    class << self
      attr_accessor :handled
    end

    def handle_error(_error)
      self.class.handled = true
      false
    end

    def render
      H[ErrorChild, should_fail: @__props[:should_fail]]
    end
  end

  class FailingHandlerBoundary < Mayu::Component::Base
    def handle_error(_error)
      raise "handler failed"
    end

    def render
      H[ErrorChild, should_fail: @__props[:should_fail]]
    end
  end

  class OuterBoundary < Mayu::Component::Base
    class << self
      attr_accessor :instance
    end

    attr_reader :error_message

    def initialize
      self.class.instance = self
      @should_fail = false
      @error_message = nil
    end

    def trigger_error
      @should_fail = true
      rerender!
    end

    def handle_error(error)
      @error_message = error.message
      true
    end

    def render
      return H[:div, "Outer handled: #{@error_message}"] if @error_message
      boundary = @__props[:boundary] || FailingFallbackBoundary
      H[boundary, should_fail: @should_fail]
    end
  end

  class InitialBoundary < Mayu::Component::Base
    def initialize
      @error = nil
    end

    def handle_error(error)
      @error = error.message
      true
    end

    def render
      return H[:div, "Initial fallback: #{@error}"] if @error
      H[ErrorChild, should_fail: true]
    end
  end

  class InitialOuterBoundary < Mayu::Component::Base
    def initialize
      @error = nil
    end

    def handle_error(error)
      @error = error.message
      true
    end

    def render
      return H[:div, "Initial outer fallback: #{@error}"] if @error
      H[ChildFailingFallbackBoundary, should_fail: true]
    end
  end

  class UpdatedBeforeFailure < Mayu::Component::Base
    def handle_click
    end

    def render
      H[
        :section,
        H[:button, "button", onclick: H.callback(self, :handle_click)],
        (@__props[:text] == "new") ? H[:span, "new"] : nil
      ]
    end
  end

  class TransactionalBoundary < Mayu::Component::Base
    class << self
      attr_accessor :instance
    end

    def initialize
      self.class.instance = self
      @changed = false
      @handled = false
    end

    def trigger_error
      @changed = true
      rerender!
    end

    def handle_error(_error)
      @handled = true
      true
    end

    def render
      return H[:div, "fallback"] if @handled

      H[
        :div,
        H[UpdatedBeforeFailure, text: @changed ? "new" : "old"],
        H[ErrorChild, should_fail: @changed],
        H[:span, "after"]
      ]
    end
  end

  class CreatedListenerBeforeFailure < Mayu::Component::Base
    def handle_click
    end

    def render
      H[:button, "new listener", onclick: H.callback(self, :handle_click)]
    end
  end

  class ListenerCreationBoundary < Mayu::Component::Base
    class << self
      attr_accessor :instance
    end

    def initialize
      self.class.instance = self
      @fail = false
      @handled = false
    end

    def trigger_error
      @fail = true
      rerender!
    end

    def handle_error(_error)
      @handled = true
      true
    end

    def render
      return H[:div, "listener fallback"] if @handled

      H[
        :div,
        (@fail ? H[CreatedListenerBeforeFailure] : nil),
        H[ErrorChild, should_fail: @fail]
      ]
    end
  end

  class StatefulBoundary < Mayu::Component::Base
    class << self
      attr_accessor :instance
    end

    attr_reader :render_count

    def initialize
      self.class.instance = self
      @__state[:failed] = false
      @__state[:handled] = false
      @render_count = 0
    end

    def trigger_error
      @__state[:failed] = true
    end

    def handle_error(_error)
      @__state[:handled] = true
      true
    end

    def render
      @render_count += 1
      return H[:div, "state fallback"] if @__state[:handled]
      H[ErrorChild, should_fail: @__state[:failed]]
    end
  end

  class UnrelatedUpdate < Mayu::Component::Base
    class << self
      attr_accessor :instance
    end

    def initialize
      self.class.instance = self
      @text = "before"
    end

    def update_text
      @text = "unrelated update"
      rerender!
    end

    def render
      H[:p, @text]
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

  def test_direct_child_updates_are_caught_by_the_parent_boundary
    descriptor = H[:body, H[DirectErrorBoundary]]

    run_engine(descriptor) do |engine|
      wait_until do
        DirectErrorChild.instance.instance_variable_get(:@__vnode_task)
      end
      DirectErrorChild.instance.trigger_error

      Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      assert_includes(
        render_html(engine.root),
        "<div>Handled: direct child failed</div>"
      )
    end
  end

  def test_boundaries_do_not_handle_their_own_render_errors
    descriptor = H[:body, H[SelfFailingBoundary]]

    run_engine(descriptor) do |engine|
      wait_until do
        SelfFailingBoundary.instance.instance_variable_get(:@__vnode_task)
      end
      SelfFailingBoundary.instance.trigger_error

      patches =
        dequeue_until(engine) do |commands|
          commands.any? { it.is_a?(Mayu::Runtime::Commands::RenderError) }
        end

      assert_equal(0, SelfFailingBoundary.instance.handled)
      assert_equal("self failed", patches.last.message)
    end
  end

  def test_a_failing_fallback_continues_to_the_next_parent_boundary
    descriptor = H[:body, H[OuterBoundary]]

    run_engine(descriptor) do |engine|
      wait_until { OuterBoundary.instance.instance_variable_get(:@__vnode_task) }
      OuterBoundary.instance.trigger_error

      Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      assert_equal("fallback failed", OuterBoundary.instance.error_message)
      assert_includes(
        render_html(engine.root),
        "<div>Outer handled: fallback failed</div>"
      )
    end
  end

  def test_a_failing_fallback_child_skips_the_failed_boundary
    descriptor =
      H[:body, H[OuterBoundary, boundary: ChildFailingFallbackBoundary]]

    run_engine(descriptor) do |engine|
      wait_until { OuterBoundary.instance.instance_variable_get(:@__vnode_task) }
      OuterBoundary.instance.trigger_error

      Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      assert_equal("boom", OuterBoundary.instance.error_message)
      assert_includes(
        render_html(engine.root),
        "<div>Outer handled: boom</div>"
      )
    end
  end

  def test_a_falsey_handler_continues_to_the_next_parent_boundary
    DecliningBoundary.handled = false
    descriptor = H[:body, H[OuterBoundary, boundary: DecliningBoundary]]

    run_engine(descriptor) do |engine|
      wait_until { OuterBoundary.instance.instance_variable_get(:@__vnode_task) }
      OuterBoundary.instance.trigger_error

      Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      assert(DecliningBoundary.handled)
      assert_equal("boom", OuterBoundary.instance.error_message)
    end
  end

  def test_a_failing_handler_continues_to_the_next_parent_boundary
    descriptor = H[:body, H[OuterBoundary, boundary: FailingHandlerBoundary]]

    run_engine(descriptor) do |engine|
      wait_until { OuterBoundary.instance.instance_variable_get(:@__vnode_task) }
      OuterBoundary.instance.trigger_error

      Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      assert_equal("handler failed", OuterBoundary.instance.error_message)
    end
  end

  def test_boundaries_handle_errors_while_building_the_initial_tree
    engine =
      Mayu::Runtime::Engine.new(
        H[:body, H[InitialBoundary]],
        metrics: NullMetrics.new
      )

    assert_includes(
      render_html(engine.root),
      "<div>Initial fallback: boom</div>"
    )
  end

  def test_a_failing_initial_fallback_child_continues_to_the_parent
    engine =
      Mayu::Runtime::Engine.new(
        H[:body, H[InitialOuterBoundary]],
        metrics: NullMetrics.new
      )

    assert_includes(
      render_html(engine.root),
      "<div>Initial outer fallback: boom</div>"
    )
  end

  def test_handled_errors_discard_commands_from_the_abandoned_render
    descriptor = H[:body, H[TransactionalBoundary]]

    run_engine(descriptor) do |engine|
      wait_until do
        TransactionalBoundary.instance.instance_variable_get(:@__vnode_task)
      end
      abandoned_element = find_element(engine.root, :section)
      abandoned_listener_ids =
        engine.root.instance_variable_get(:@listeners).keys
      TransactionalBoundary.instance.trigger_error

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      commands = unwrap_commands(batch)

      refute(commands.any? do |command|
        command.is_a?(Mayu::Runtime::Commands::SetTextContent)
      end)
      assert(commands.any? do |command|
        command.is_a?(Mayu::Runtime::Commands::CreateTree)
      end)
      refute(commands.any? do |command|
        command.is_a?(Mayu::Runtime::Commands::ReplaceChildren) &&
          command.id == abandoned_element.dom_id
      end)
      listeners = engine.root.instance_variable_get(:@listeners)
      assert_empty(abandoned_listener_ids & listeners.keys)
      assert_includes(render_html(engine.root), "<div>fallback</div>")
    end
  end

  def test_handled_errors_do_not_index_listeners_from_abandoned_subtrees
    descriptor = H[:body, H[ListenerCreationBoundary]]

    run_engine(descriptor) do |engine|
      wait_until do
        ListenerCreationBoundary.instance.instance_variable_get(:@__vnode_task)
      end

      assert_empty(engine.root.instance_variable_get(:@listeners))
      ListenerCreationBoundary.instance.trigger_error

      Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      listeners = engine.root.instance_variable_get(:@listeners)
      assert_empty(listeners)
      assert_includes(render_html(engine.root), "<div>listener fallback</div>")
    end
  end

  def test_state_changes_in_the_handler_are_recovered_synchronously
    descriptor = H[:body, H[StatefulBoundary]]

    run_engine(descriptor) do |engine|
      wait_until { StatefulBoundary.instance.instance_variable_get(:@__vnode_task) }
      initial_render_count = StatefulBoundary.instance.render_count
      StatefulBoundary.instance.trigger_error

      Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      wait_until do
        engine.instance_variable_get(:@updater).queue.empty?
      end

      assert_equal(initial_render_count + 2, StatefulBoundary.instance.render_count)
      assert_includes(render_html(engine.root), "<div>state fallback</div>")
    end
  end

  def test_recovery_preserves_completed_unrelated_updates_in_the_batch
    descriptor =
      H[:body, H[UnrelatedUpdate], H[TransactionalBoundary]]

    run_engine(descriptor) do |engine|
      wait_until do
        UnrelatedUpdate.instance.instance_variable_get(:@__vnode_task) &&
          TransactionalBoundary.instance.instance_variable_get(:@__vnode_task)
      end

      UnrelatedUpdate.instance.update_text
      TransactionalBoundary.instance.trigger_error

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      commands = unwrap_commands(batch)

      assert(commands.any? do |command|
        command.is_a?(Mayu::Runtime::Commands::SetTextContent) &&
          command.content == "unrelated update"
      end)
      assert_includes(render_html(engine.root), "<p>unrelated update</p>")
      assert_includes(render_html(engine.root), "<div>fallback</div>")
    end
  end

  def test_render_error_overlay_can_be_disabled_without_stopping_updates
    descriptor = H[:body, H[RenderErrorProbe]]
    engine =
      Mayu::Runtime::Engine.new(
        descriptor,
        metrics: NullMetrics.new,
        render_exceptions: false
      )

    run_engine_instance(engine) do
      component = find_component(engine.root, RenderErrorProbe)
      instance = component.instance_variable_get(:@instance)
      wait_until { instance.instance_variable_get(:@__vnode_task) }

      instance.trigger_error
      assert_no_patches(engine)

      instance.recover
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      assert(unwrap_commands(batch).any? do |command|
        command.is_a?(Mayu::Runtime::Commands::SetTextContent)
      end)
    end
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
        [{name: "CodeReload".b, path: "app:/broken.haml".b}],
        2,
        4,
        ["Did you mean ./colors.json?".b]
      ]

    serialized = MessagePack.unpack(MessagePack.pack(patch))

    assert_equal("RenderError", serialized[0])
    assert_equal("app:/broken.haml", serialized[1])
    assert_equal("SyntaxError", serialized[2])
    assert_equal("unexpected token", serialized[3])
    assert_equal(["app:/broken.haml:2"], serialized[4])
    assert_equal("%p= )\n", serialized[5])
    assert_equal({"name" => "CodeReload", "path" => "app:/broken.haml"}, serialized[6][0])
    assert_equal(2, serialized[7])
    assert_equal(4, serialized[8])
    assert_equal(["Did you mean ./colors.json?"], serialized[9])
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
