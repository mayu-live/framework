#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::PatchesTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

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

    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root

    collector = Mayu::Runtime::VNodes::CommandCollector.new

    document.update(collector, updated)

    create_patch =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::CreateTree)
      end
    remove_patch =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::RemoveNode)
      end

    refute_nil(create_patch)
    refute_nil(remove_patch)

    assert_match("<section><h2>News</h2></section>", create_patch.html)
    refute_nil(remove_patch.id)
  end

  def test_register_custom_element_patch
    custom = Mayu::CustomElement["my-element", "my-element.js"]
    initial = H[:body]
    updated = H[:body, H[custom, H[:span, "Hello"]]]

    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root

    collector = Mayu::Runtime::VNodes::CommandCollector.new
    document.update(collector, updated)

    register =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::RegisterCustomElement)
      end

    refute_nil(register)
    assert_equal("my-element", register.name)
    assert_equal("/.mayu/assets/my-element.js", register.path)
  end

  def test_registers_a_klenod_custom_element_descriptor
    custom = {
      __klenod_custom_element: true,
      tag: "klenod-clock-a1b2c3d4",
      asset_path: "/.mayu/assets/clock.a1b2c3d4.js"
    }
    initial = H[:body]
    updated = H[:body, H[custom]]

    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    collector = Mayu::Runtime::VNodes::CommandCollector.new
    engine.root.update(collector, updated)

    register =
      collector.commands.find do
        it.is_a?(Mayu::Runtime::Commands::RegisterCustomElement)
      end

    assert_equal("klenod-clock-a1b2c3d4", register.name)
    assert_equal("/.mayu/assets/clock.a1b2c3d4.js", register.path)
  end

  def test_update_patches_for_attribute_and_text
    initial = H[:body, H[:p, "Hello", class: ["greeting"]]]
    updated =
      H[:body, H[:p, "World", class: ["farewell"], style: {color: "red"}]]

    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root

    collector = Mayu::Runtime::VNodes::CommandCollector.new

    document.update(collector, updated)

    add_class =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::AddClass)
      end
    remove_class =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::RemoveClass)
      end
    set_css =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::SetCSSProperty)
      end
    set_text =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::SetTextContent)
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

  def test_class_patches_split_whitespace_separated_class_names
    initial = H[:body, H[:p, "Hello", class: "first second"]]
    updated = H[:body, H[:p, "Hello", class: "second third"]]
    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    collector = Mayu::Runtime::VNodes::CommandCollector.new

    engine.root.update(collector, updated)

    add_class =
      collector.commands.find { it.is_a?(Mayu::Runtime::Commands::AddClass) }
    remove_class =
      collector.commands.find { it.is_a?(Mayu::Runtime::Commands::RemoveClass) }

    assert_equal(["third"], add_class.classes)
    assert_equal(["first"], remove_class.classes)
  end

  def test_class_and_style_removal_patches
    initial =
      H[:body, H[:p, "Hello", class: ["greeting"], style: {color: "red"}]]
    updated = H[:body, H[:p, "Hello", class: [], style: {}]]

    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root

    collector = Mayu::Runtime::VNodes::CommandCollector.new
    document.update(collector, updated)

    remove_class_attr =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::RemoveAttribute) &&
          patch.name == :class
      end
    remove_style_attr =
      collector.commands.find do |patch|
        patch.is_a?(Mayu::Runtime::Commands::RemoveAttribute) &&
          patch.name == :style
      end

    refute_nil(remove_class_attr)
    refute_nil(remove_style_attr)
  end

  def test_component_update_queue_emits_patches
    descriptor = H[:body, H[MountUpdateProbe]]

    run_engine(descriptor) do |engine|
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

      set_text =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::SetTextContent)
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

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

      replace_children =
        patches.select do |patch|
          patch.is_a?(Mayu::Runtime::Commands::ReplaceChildren)
        end

      assert_equal(1, replace_children.count)
    end
  end

  def test_navigation_emits_history_and_dom_patches
    initial = H[:body, H[:p, "before"]]
    updated = H[:body, H[:p, "after"]]

    run_engine(initial) do |engine|
      engine.navigate("/next", updated)

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

      history =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::HistoryPushState)
        end
      dom_patches =
        patches.reject do |patch|
          patch.is_a?(Mayu::Runtime::Commands::HistoryPushState)
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

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

      create_tree =
        patches.find { |patch| patch.is_a?(Mayu::Runtime::Commands::CreateTree) }
      replace_children =
        patches.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::ReplaceChildren)
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

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

      create_trees =
        patches.select do |patch|
          patch.is_a?(Mayu::Runtime::Commands::CreateTree)
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
    initial = H[:body]
    updated = H[:body, H[MultiRootProbe]]

    engine = Mayu::Runtime::Engine.new(initial, metrics: NullMetrics.new)
    document = engine.root

    collector = Mayu::Runtime::VNodes::CommandCollector.new

    assert_raises(RuntimeError) { document.update(collector, updated) }
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

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

      assert(patches.first.is_a?(Mayu::Runtime::Commands::HistoryPushState))
      assert(
        patches.any? do |patch|
          patch.is_a?(Mayu::Runtime::Commands::HistoryPushState)
        end
      )

      assert(
        patches.any? do |patch|
          patch.is_a?(Mayu::Runtime::Commands::ReplaceChildren)
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

      patches =
        dequeue_until(engine) do |batch_patches|
          batch_patches.any? do |patch|
            patch.is_a?(Mayu::Runtime::Commands::SetTextContent)
          end
        end

      set_text =
        patches&.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::SetTextContent)
        end

      refute_nil(set_text)
      assert_equal("B", set_text.content)
    end
  end

  class RemovedUpdateProbe < Mayu::Component::Base
    attr_reader :touched

    def initialize
      @touched = false
    end

    def touch
      @touched = true
      rerender!
    end

    def render
      H[:div, @touched ? "touched" : "idle"]
    end
  end

  class RemoveParentProbe < Mayu::Component::Base
    def initialize
      @show = true
    end

    def hide!
      @show = false
      rerender!
    end

    def render
      @show ? H[:section, H[RemovedUpdateProbe]] : H[:section]
    end
  end

  def test_removed_nodes_are_not_updated
    descriptor = H[:body, H[RemoveParentProbe]]

    run_engine(descriptor) do |engine|
      parent = find_component(engine.root, RemoveParentProbe)
      parent_instance = parent.instance_variable_get(:@instance)

      wait_until { parent_instance.instance_variable_get(:@__vnode_task) }

      removed = find_component(engine.root, RemovedUpdateProbe)
      removed_instance = removed.instance_variable_get(:@instance)

      removed_instance.touch
      parent_instance.hide!

      wait_until { removed.removed? }

      first_batch =
        dequeue_until(engine, max_batches: 3) do |batch_patches|
          batch_patches.any? do |patch|
            patch.is_a?(Mayu::Runtime::Commands::ReplaceChildren)
          end
        end

      refute_nil(first_batch)
      replace =
        first_batch.find do |patch|
          patch.is_a?(Mayu::Runtime::Commands::ReplaceChildren)
        end
      refute_nil(replace)
      assert_equal([], replace.child_ids)

      engine.enqueue_update(removed)

      second_batch =
        dequeue_until(engine, max_batches: 1) do |batch_patches|
          batch_patches.any? do |patch|
            patch.is_a?(Mayu::Runtime::Commands::SetTextContent)
          end
        end

      assert_nil(second_batch)
      assert(removed_instance.touched)
    end
  end

  class BudgetProbe < Mayu::Component::Base
    def initialize
      @count = 1
    end

    def expand!
      @count = 3
      rerender!
    end

    def render
      H[:ul, (1..@count).map { |i| H[:li, "Item #{i}"] }]
    end
  end

  def test_update_budget_splits_batches
    descriptor = H[:body, H[BudgetProbe]]

    run_engine(descriptor) do |engine|
      engine.update_budget = 1

      component = find_component(engine.root, BudgetProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.instance_variable_get(:@__vnode_task) }
      instance.expand!

      first =
        dequeue_until(engine, max_batches: 1) do |batch_patches|
          !batch_patches.empty?
        end

      second =
        dequeue_until(engine, max_batches: 2) do |batch_patches|
          !batch_patches.empty?
        end

      refute_nil(first)
      refute_nil(second)
    end
  end
end
