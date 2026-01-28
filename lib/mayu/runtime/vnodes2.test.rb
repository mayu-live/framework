#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "minitest/autorun"
require "minitest/focus"
require "stringio"
require_relative "../test"
require_relative "../modules/system"
require_relative "vnodes2/vdocument"
require_relative "vnodes2/engine"
require_relative "vnodes2/patcher"

class Mayu::Runtime::VNodes2Test < Minitest::Test
  H = Mayu::Runtime::H

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

  class RenderProbe < Mayu::Component::Base
    def render
      H[:section, H[:h2, "Rendered"], H[:p, "From component"]]
    end
  end

  class HeadProbe < Mayu::Component::Base
    def initialize
      @enabled = false
    end

    def enable!
      @enabled = true
      rerender!
    end

    def disable!
      @enabled = false
      rerender!
    end

    def render
      [(@enabled ? H[:head, H[:title, "Enabled"]] : nil), H[:main, "content"]]
    end
  end

  class HeadToggleProbe < Mayu::Component::Base
    def initialize
      @mode = :a
    end

    def set_mode(mode)
      @mode = mode
      rerender!
    end

    def render
      case @mode
      when :a
        [
          H[:head, H[:title, "A"]],
          H[:head, H[:title, "B"]],
          H[:main, "content"]
        ]
      when :b
        [H[:head, H[:title, "C"]], H[:main, "content"]]
      else
        [H[:main, "content"]]
      end
    end
  end

  class MountUpdateProbe < Mayu::Component::Base
    def initialize
      @value = "before"
    end

    def mount
      @value = "after"
      rerender!
    end

    def render
      H[:p, @value]
    end
  end

  class ReplaceChildrenProbe < Mayu::Component::Base
    def initialize
      @mode = :a
    end

    def set_mode(mode)
      @mode = mode
      rerender!
    end

    def render
      case @mode
      when :a
        H[:section, H[:div, "a"], H[:div, "b"]]
      else
        H[:section, H[:div, "c"]]
      end
    end
  end

  class StylesProbe < Mayu::Component::Base
    def self.module_path = "/styles/probe"

    def render
      H[:div, "styles"]
    end
  end

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

  class ViewTransitionChildProbe < Mayu::Component::Base
    def render
      H[:span, @__props[:value].to_s]
    end
  end

  class ViewTransitionProbe < Mayu::Component::Base
    def initialize
      @value = 0
    end

    def increment
      view_transition do
        @value += 1
        rerender!
      end
    end

    def render
      H[:div, H[ViewTransitionChildProbe, value: @value]]
    end
  end

  def test_write_html
    descriptor =
      H[
        :body,
        H[:header, H[:h1, "My webpage"]],
        H[:main, H[:p, "Welcome"]],
        H[:footer, H[:p, "Copyright"]]
      ]

    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)
    html = render_html(engine.root)

    assert_equal(
      "<!DOCTYPE html>\n" \
        "<html><head><meta charset=\"utf-8\"></head>" \
        "<body><header><h1>My webpage</h1></header>" \
        "<main><p>Welcome</p></main>" \
        "<footer><p>Copyright</p></footer>" \
        "<mayu-ping ping=\"N/A\"></mayu-ping></body></html>\n",
      html
    )
  end

  def test_update_patches_for_insert_and_remove
    initial =
      H[
        :body,
        H[:header, H[:h1, "My webpage"]],
        H[:main, H[:p, "Welcome"]],
        H[:footer, H[:p, "Copyright"]]
      ]

    updated =
      H[
        :body,
        H[:header, H[:h1, "My webpage"]],
        H[:main, H[:p, "Welcome"]],
        H[:section, H[:h2, "News"]]
      ]

    engine = Mayu::Runtime::VNodes2::Engine.new(initial)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new

    document.update(patcher, updated)

    create_patch =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::CreateTree)
      end
    remove_patch =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::RemoveNode)
      end

    refute_nil(create_patch)
    refute_nil(remove_patch)

    assert_match("<section><h2>News</h2></section>", create_patch.html)
    refute_nil(remove_patch.id)
  end

  def test_update_patches_for_attribute_and_text
    initial = H[:body, H[:p, "Hello", class: ["greeting"]]]
    updated = H[:body, H[:p, "World", class: ["farewell"]]]

    engine = Mayu::Runtime::VNodes2::Engine.new(initial)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new

    document.update(patcher, updated)

    set_attribute =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::SetAttribute) &&
          patch.name == :class
      end
    set_text =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
      end

    refute_nil(set_attribute)
    assert_equal("farewell", set_attribute.value)

    refute_nil(set_text)
    assert_equal("World", set_text.content)
  end

  def test_component_renders_html
    descriptor = H[:body, H[RenderProbe]]

    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)
    html = render_html(engine.root)

    assert_match(
      "<section><h2>Rendered</h2><p>From component</p></section>",
      html
    )
  end

  def test_head_nodes_register_and_unregister
    descriptor = H[:body, H[HeadProbe]]
    run_engine(descriptor) do |engine|
      document = engine.root
      component = find_component(document, HeadProbe)
      instance = component.instance_variable_get(:@instance)

      assert_equal(0, document.head.size)

      wait_until { instance.respond_to?(:rerender!) }

      instance.enable!

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      refute_nil(patches)
      assert_equal(1, document.head.size)

      instance.disable!
      Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      assert_equal(0, document.head.size)
    end
  end

  def test_head_render_without_start
    descriptor = H[:body, H[:head, H[:title, "Static"]], H[:main, "content"]]
    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

    html = render_html(engine.root)

    assert_match("<title>Static</title>", html)
  end

  def test_head_updates_with_multiple_titles
    descriptor = H[:body, H[HeadToggleProbe]]
    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)
    html = render_html(engine.root)
    assert_equal(1, html.scan("<title>").length)
    assert_match("<title>B</title>", html)

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, HeadToggleProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.set_mode(:b)

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      refute_nil(patches)
      refute_empty(patches)

      html = render_html(engine.root)
      assert_equal(1, html.scan("<title>").length)
      assert_match("<title>C</title>", html)
    end
  end

  def test_component_start_stop_and_rerender
    descriptor = H[:body, H[MountProbe]]

    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)
    document = engine.root
    html = render_html(document)

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

  def test_component_update_queue_emits_patches
    descriptor = H[:body, H[MountUpdateProbe]]
    run_engine(descriptor) do |engine|
      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      set_text =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("after", set_text.content)
    end
  end

  def test_replace_children_emitted_once_per_batch
    descriptor = H[:body, H[ReplaceChildrenProbe]]
    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ReplaceChildrenProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.set_mode(:b)

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      replace_children =
        patches.select do |patch|
          patch.is_a?(Mayu::Runtime::Patches::ReplaceChildren)
        end

      assert_equal(1, replace_children.count)
    end
  end

  def test_component_stylesheet_registration
    mod = Data.define(:assets, :dependencies).new(["styles.css"], [])
    system =
      Data
        .define(:mod) do
          def get_mod(_path)
            mod
          end
        end
        .new(mod)

    key = Mayu::Modules::System::CURRENT_KEY
    previous = Thread.current.thread_variable_get(key)
    Thread.current.thread_variable_set(key, system)

    descriptor = H[:body, H[StylesProbe]]
    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

    html = render_html(engine.root)

    assert_match(
      '<link rel="stylesheet" href="/.mayu/assets/styles.css">',
      html
    )
  ensure
    Thread.current.thread_variable_set(key, previous)
  end

  def test_event_callback_attribute
    component = CallbackProbe.new
    initial = H[:body, H[:button, "Click"]]
    updated =
      H[
        :body,
        H[:button, "Click", onclick: H.callback(component, :handle_click)]
      ]

    engine = Mayu::Runtime::VNodes2::Engine.new(initial)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new
    document.update(patcher, updated)

    set_attribute =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::SetAttribute) &&
          patch.name == :onclick
      end

    refute_nil(set_attribute)
    assert_match(
      /\AMayu\.callback\(event,'[A-Za-z0-9]+'\)\z/,
      set_attribute.value
    )
  end

  def test_event_listener_unregistered_on_change
    component = CallbackProbe.new
    initial =
      H[
        :body,
        H[:button, "Click", onclick: H.callback(component, :handle_click)]
      ]
    updated = H[:body, H[:button, "Click", onclick: nil]]

    engine = Mayu::Runtime::VNodes2::Engine.new(initial)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new
    document.update(patcher, initial)

    listeners = document.instance_variable_get(:@listeners)
    assert_equal(1, listeners.size)

    patcher = Mayu::Runtime::VNodes2::Patcher.new
    document.update(patcher, updated)

    remove_attribute =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::RemoveAttribute) &&
          patch.name == :onclick
      end

    refute_nil(remove_attribute)
    assert_equal(0, listeners.size)
  end

  def test_engine_callback_emits_patches
    initial = H[:body, H[CallbackProbe]]

    run_engine(initial) do |engine|
      document = engine.root

      patcher = Mayu::Runtime::VNodes2::Patcher.new
      document.update(patcher, initial)

      component = find_component(document, CallbackProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until do
        document.instance_variable_get(:@listeners).any? &&
          instance.singleton_methods.include?(:rerender!)
      end

      listener = document.instance_variable_get(:@listeners).values.first
      refute_nil(listener)

      engine.callback(listener.id, {})

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      set_text =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("Click 1", set_text.content)
    end
  end

  def test_engine_serialization_round_trip
    descriptor = H[:body, H[SerializeProbe]]

    with_modules_system(SerializeProbe) do
      engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

      run_engine_instance(engine) do
        component = find_component(engine.root, SerializeProbe)
        instance = component.instance_variable_get(:@instance)

        wait_until { instance.respond_to?(:rerender!) }

        instance.bump
        Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
        instance.bump
        Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

        assert_equal(2, instance.count)
        assert_equal(1, instance.mount_count)
        assert_equal(0, instance.unmount_count)
      end

      dumped = engine.dump!
      restored = Mayu::Runtime::VNodes2::Engine.restore(dumped)

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
      engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

      run_engine_instance(engine) do
        document = engine.root
        patcher = Mayu::Runtime::VNodes2::Patcher.new
        document.update(patcher, descriptor)

        wait_until { document.instance_variable_get(:@listeners).any? }
      end

      dumped = engine.dump!
      restored = Mayu::Runtime::VNodes2::Engine.restore(dumped)

      listeners = restored.root.instance_variable_get(:@listeners)
      assert_equal(0, listeners.size)

      listener = listeners.values.first
      assert_nil(listener)

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
        patches =
          Async::Task.current.with_timeout(0.5) { restored.dequeue_patches }

        set_text =
          patches.find do |patch|
            patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
          end

        refute_nil(set_text)
        assert_equal("Click 1", set_text.content)
      end
    end
  end

  def test_error_boundary_rerenders_on_error
    descriptor = H[:body, H[ErrorBoundaryProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ErrorBoundaryProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.trigger_error

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      refute_nil(patches)

      html = render_html(engine.root)
      assert_match("<div>Error handled</div>", html)
    end
  end

  def test_error_boundary_render_html
    descriptor = H[:body, H[ErrorBoundaryProbe]]
    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

    component = find_component(engine.root, ErrorBoundaryProbe)
    instance = component.instance_variable_get(:@instance)
    instance.instance_variable_set(:@should_fail, true)

    html = render_html(engine.root)
    assert_match("<div>Error handled</div>", html)
  end

  def test_view_transition_wraps_patches
    descriptor = H[:body, H[ViewTransitionProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ViewTransitionProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.increment

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      assert_equal(1, patches.size)
      assert_kind_of(Mayu::Runtime::Patches::ViewTransition, patches.first)

      inner = patches.first.patches
      set_text =
        inner.find do |patch|
          patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("1", set_text.content)
    end
  end

  def test_view_transition_not_used_for_regular_rerender
    descriptor = H[:body, H[ViewTransitionProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ViewTransitionProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.instance_variable_set(:@value, 1)
      instance.rerender!

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      refute_empty(patches)
      refute_kind_of(Mayu::Runtime::Patches::ViewTransition, patches.first)
    end
  end

  private

  def run_engine(descriptor)
    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

    Async do
      engine.start
      yield engine
    ensure
      engine.stop
    end.wait
  end

  def run_engine_instance(engine)
    Async do
      engine.start
      yield
    ensure
      engine.stop
    end.wait
  end

  def with_modules_system(component_class)
    mod = Module.new
    exports = Module.new
    exports.const_set(component_class.name.split("::").last, component_class)
    mod.const_set(:Exports, exports)
    mod.define_singleton_method(:assets) { [] }
    mod.define_singleton_method(:dependencies) { [] }

    system =
      Data
        .define(:mod) do
          def get_mod(_path)
            mod
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

  def wait_until(timeout: 0.2)
    deadline = Async::Clock.now + timeout

    until yield
      raise "timed out waiting for condition" if Async::Clock.now >= deadline
      Async::Task.current.sleep(0)
    end
  end

  def render_html(document)
    out = StringIO.new
    document.write_html(out)
    out.tap(&:rewind).read
  end

  def find_component(node, klass)
    if node.is_a?(Mayu::Runtime::VNodes2::VComponent)
      instance = node.instance_variable_get(:@instance)
      return node if instance.is_a?(klass)
    end

    case node
    when Mayu::Runtime::VNodes2::VDocument
      find_component(node.instance_variable_get(:@html), klass)
    when Mayu::Runtime::VNodes2::VAny
      find_component(node.instance_variable_get(:@child), klass)
    when Mayu::Runtime::VNodes2::VComponent
      find_component(node.instance_variable_get(:@children), klass)
    when Mayu::Runtime::VNodes2::VElement
      find_component(node.instance_variable_get(:@children), klass)
    when Mayu::Runtime::VNodes2::VCustomElement
      find_component(node.instance_variable_get(:@element), klass)
    when Mayu::Runtime::VNodes2::VSlot, Mayu::Runtime::VNodes2::VStateless
      find_component(node.instance_variable_get(:@children), klass)
    when Mayu::Runtime::VNodes2::VChildren
      node
        .instance_variable_get(:@children)
        .each do |child|
          found = find_component(child, klass)
          return found if found
        end
      nil
    else
      nil
    end
  end
end
