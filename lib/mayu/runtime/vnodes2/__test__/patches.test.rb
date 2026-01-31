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
    updated =
      H[:body, H[:p, "World", class: ["farewell"], style: { color: "red" }]]

    engine = Mayu::Runtime::VNodes2::Engine.new(initial)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new

    document.update(patcher, updated)

    add_class =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::AddClass)
      end
    remove_class =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::RemoveClass)
      end
    set_css =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::SetCSSProperty)
      end
    set_text =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
      end

    refute_nil(add_class)
    assert_equal(["farewell"], add_class.classes)
    refute_nil(remove_class)
    assert_equal(["greeting"], remove_class.classes)
    refute_nil(set_css)
    assert_equal("color", set_css.name)
    assert_equal("red", set_css.value)

    refute_nil(set_text)
    assert_equal("World", set_text.content)
  end

  def test_class_and_style_removal_patches
    initial =
      H[:body, H[:p, "Hello", class: ["greeting"], style: { color: "red" }]]
    updated = H[:body, H[:p, "Hello", class: [], style: {}]]

    engine = Mayu::Runtime::VNodes2::Engine.new(initial)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new
    document.update(patcher, updated)

    remove_class_attr =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::RemoveAttribute) &&
          patch.name == :class
      end
    remove_style_attr =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::RemoveAttribute) &&
          patch.name == :style
      end

    refute_nil(remove_class_attr)
    refute_nil(remove_style_attr)
  end

  def test_component_update_queue_emits_patches
    descriptor = H[:body, H[MountUpdateProbe]]

    run_engine(descriptor) do |engine|
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

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

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      replace_children =
        patches.select do |patch|
          patch.is_a?(Mayu::Runtime::Patches::ReplaceChildren)
        end

      assert_equal(1, replace_children.count)
    end
  end

  def test_navigation_emits_history_and_dom_patches
    initial = H[:body, H[:p, "before"]]
    updated = H[:body, H[:p, "after"]]

    run_engine(initial) do |engine|
      engine.navigate("/next", updated)

      # puts render_html(engine.root)
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      history =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Patches::HistoryPushState)
        end
      dom_patches =
        patches.reject do |patch|
          patch.is_a?(Mayu::Runtime::Patches::HistoryPushState)
        end

      refute_nil(history)
      assert_equal("/next", history.path)
      refute_empty(dom_patches)
    end
  end

  def test_navigation_emits_replace_children_for_complex_tree
    initial =
      H[
        :body,
        H[:main, H[:section, H[:h1, "Title"]], H[:section, H[:p, "Intro"]]],
        H[:footer, H[:p, "Footer"]]
      ]

    updated =
      H[
        :body,
        H[
          :main,
          H[:section, H[:h1, "Title"]],
          H[:section, H[:p, "Intro"]],
          H[:section, H[:p, "New"]]
        ],
        H[:footer, H[:p, "Footer"]]
      ]

    run_engine(initial) do |engine|
      engine.navigate("/complex", updated)

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      create_tree =
        patches.find { |patch| patch.is_a?(Mayu::Runtime::Patches::CreateTree) }
      replace_children =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Patches::ReplaceChildren)
        end

      refute_nil(create_tree)
      assert_includes(create_tree.html, "<p>New</p>")
      refute_nil(replace_children)
      main = find_element(engine.root, :main)
      refute_nil(main)
      assert_equal(main.dom_id, replace_children.id)
      assert_includes(replace_children.child_ids, create_tree.tree.id)
      assert_equal(3, replace_children.child_ids.length)
    end
  end

  def test_navigation_creates_single_tree_for_nested_insert
    initial = H[:body, H[:main]]
    updated = H[:body, H[:main, H[:section, H[:div, H[:span, "Nested"]]]]]

    run_engine(initial) do |engine|
      engine.navigate("/tree", updated)

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      create_trees =
        patches.select do |patch|
          patch.is_a?(Mayu::Runtime::Patches::CreateTree)
        end

      assert_equal(1, create_trees.length)
      assert_includes(create_trees.first.html, "<span>Nested</span>")
    end
  end

  class MultiRootProbe < Mayu::Component::Base
    def render
      [H[:p, "a"], H[:p, "b"]]
    end
  end

  def test_createtree_requires_single_root
    descriptor = H[:body, H[MultiRootProbe]]
    engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)
    document = engine.root

    patcher = Mayu::Runtime::VNodes2::Patcher.new

    assert_raises(RuntimeError) { document.update(patcher, descriptor) }
  end

  class HeadNavProbe < Mayu::Component::Base
    def initialize
      @title = "A"
    end

    def set_title(value)
      @title = value
      rerender!
    end

    def render
      [H[:head, H[:title, @title]], H[:main, H[:p, "Content"]]]
    end
  end

  def test_navigation_emits_history_before_head
    initial = H[:body, H[HeadNavProbe]]
    updated = H[:body, H[HeadNavProbe]]

    run_engine(initial) do |engine|
      component = find_component(engine.root, HeadNavProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.instance_variable_get(:@__vnode_task) }
      instance.set_title("B")

      engine.navigate("/nav", updated)

      history_batch =
        Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      head_batch =
        Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }

      history_patches = unwrap_patches(history_batch)
      head_patches = unwrap_patches(head_batch)

      assert(
        history_patches.all? do |patch|
          patch.is_a?(Mayu::Runtime::Patches::HistoryPushState)
        end
      )

      assert(
        head_patches.any? do |patch|
          patch.is_a?(Mayu::Runtime::Patches::ReplaceChildren)
        end
      )
    end
  end

  class ReloadProbe < Mayu::Component::Base
    def initialize
      @value = "A"
    end

    def set_value(value)
      @value = value
    end

    def render
      H[:p, @value]
    end
  end

  def test_engine_refresh_enqueues_root_update
    descriptor = H[:body, H[ReloadProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ReloadProbe)
      instance = component.instance_variable_get(:@instance)
      instance.set_value("B")

      updated = H[:body, H[ReloadProbe]]
      engine.refresh(updated)

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      set_text =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("B", set_text.content)
    end
  end
end
