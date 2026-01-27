#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "minitest/autorun"
require "stringio"
require_relative "../test"
require_relative "vnodes2/vdocument"
require_relative "vnodes2/patcher"

class Mayu::Runtime::VNodes2Test < Minitest::Test
  H = Mayu::Runtime::H

  class EngineStub
    attr_reader :runtime_js, :updates

    def initialize(runtime_js)
      @runtime_js = runtime_js
      @updates = []
    end

    def enqueue_update(node)
      @updates << node
    end

    def task
      Async::Task.current
    end
  end

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

  def test_write_html
    descriptor =
      H[
        :body,
        H[:header, H[:h1, "My webpage"]],
        H[:main, H[:p, "Welcome"]],
        H[:footer, H[:p, "Copyright"]]
      ]

    engine = EngineStub.new(nil)

    document =
      Mayu::Runtime::VNodes2::VDocument.new(
        descriptor,
        parent: nil,
        engine: engine
      )

    out = StringIO.new
    document.write_html(out)

    assert_equal(
      "<!DOCTYPE html>\n" \
        "<html><head><meta charset=\"utf-8\"></head>" \
        "<body><header><h1>My webpage</h1></header>" \
        "<main><p>Welcome</p></main>" \
        "<footer><p>Copyright</p></footer>" \
        "<mayu-ping ping=\"N/A\"></mayu-ping></body></html>\n",
      out.tap(&:rewind).read
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

    engine = EngineStub.new(nil)

    document =
      Mayu::Runtime::VNodes2::VDocument.new(
        initial,
        parent: nil,
        engine: engine
      )

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

    engine = EngineStub.new(nil)
    document =
      Mayu::Runtime::VNodes2::VDocument.new(
        initial,
        parent: nil,
        engine: engine
      )

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

    engine = EngineStub.new(nil)
    document =
      Mayu::Runtime::VNodes2::VDocument.new(
        descriptor,
        parent: nil,
        engine: engine
      )

    out = StringIO.new
    document.write_html(out)

    html = out.tap(&:rewind).read

    assert_match(
      "<section><h2>Rendered</h2><p>From component</p></section>",
      html
    )
  end

  def test_component_start_stop_and_rerender
    descriptor = H[:body, H[MountProbe]]

    engine = EngineStub.new(nil)
    document =
      Mayu::Runtime::VNodes2::VDocument.new(
        descriptor,
        parent: nil,
        engine: engine
      )

    out = StringIO.new
    document.write_html(out)

    html = out.tap(&:rewind).read

    Async do
      document.start

      component = find_component(document, MountProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.mounted }

      instance = component.instance_variable_get(:@instance)

      assert_equal(true, instance.mounted)

      instance.rerender!
      assert_equal([component], engine.updates)

      document.stop
      assert_equal(true, instance.unmounted)
    end.wait
  end

  private

  def wait_until(timeout: 0.2)
    deadline = Async::Clock.now + timeout

    until yield
      raise "timed out waiting for condition" if Async::Clock.now >= deadline
      Async::Task.current.sleep(0)
    end
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
