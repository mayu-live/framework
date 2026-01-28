#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes2::PatchesTest < Minitest::Test
  include Mayu::Runtime::VNodes2::TestHelpers

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
end
