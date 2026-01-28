#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "minitest/autorun"
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
    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

    document = engine.root
    component = find_component(document, HeadProbe)
    instance = component.instance_variable_get(:@instance)

    assert_equal(0, document.head.size)

    Async do
      engine.start

      wait_until { instance.respond_to?(:rerender!) }

      instance.enable!

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      refute_nil(patches)
      assert_equal(1, document.head.size)

      instance.disable!
      Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      assert_equal(0, document.head.size)
    ensure
      engine.stop
    end.wait
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

    component = find_component(engine.root, HeadToggleProbe)
    instance = component.instance_variable_get(:@instance)

    Async do
      engine.start
      wait_until { instance.respond_to?(:rerender!) }

      instance.set_mode(:b)

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      refute_nil(patches)
      refute_empty(patches)

      html = render_html(engine.root)
      assert_equal(1, html.scan("<title>").length)
      assert_match("<title>C</title>", html)
    ensure
      engine.stop
    end.wait
  end

  def test_component_start_stop_and_rerender
    descriptor = H[:body, H[MountProbe]]

    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)
    document = engine.root
    html = render_html(document)

    Async do
      engine.start

      component = find_component(document, MountProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.mounted }

      instance = component.instance_variable_get(:@instance)

      assert_equal(true, instance.mounted)

      instance.rerender!

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      assert_equal([], patches)

      engine.stop
      assert_equal(true, instance.unmounted)
    end.wait
  end

  def test_component_update_queue_emits_patches
    descriptor = H[:body, H[MountUpdateProbe]]
    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

    Async do
      engine.start

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      set_text =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("after", set_text.content)
    ensure
      engine.stop
    end.wait
  end

  def test_replace_children_emitted_once_per_batch
    descriptor = H[:body, H[ReplaceChildrenProbe]]
    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

    component = find_component(engine.root, ReplaceChildrenProbe)
    instance = component.instance_variable_get(:@instance)

    Async do
      engine.start
      wait_until { instance.respond_to?(:rerender!) }

      instance.set_mode(:b)

      patches = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      replace_children =
        patches.select do |patch|
          patch.is_a?(Mayu::Runtime::Patches::ReplaceChildren)
        end

      assert_equal(1, replace_children.count)
    ensure
      engine.stop
    end.wait
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

  private

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
