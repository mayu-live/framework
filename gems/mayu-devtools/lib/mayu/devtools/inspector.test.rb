#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require "mayu/test"
require "mayu/runtime/engine"
require_relative "inspector"

class Mayu::Devtools::InspectorTest < Minitest::Test
  H = Mayu::Runtime::H

  class Item < Mayu::Component::Base
    def render
      H[:li, @label]
    end
  end

  class List < Mayu::Component::Base
    def render
      H.context(theme: "dark") { H[:ul, H[Item, label: "one"], H[Item, label: "two"]] }
    end
  end

  def test_tree_nests_components_and_elements_without_wrappers
    engine = build_engine(H[:body, H[List]])

    tree = Mayu::Devtools::Inspector.new.call(engine, {type: "tree"})
    body = find(tree) { it[:name] == "body" }
    list = body[:children].first

    assert_equal("document", tree[:type])
    assert_equal(engine.root.id, tree[:id])
    assert_equal({type: "component", name: "List", internal: false}, list.slice(:type, :name, :internal))
    assert_equal(["ul"], list[:children].map { it[:name] })
    assert_equal(
      [["component", "Item"], ["component", "Item"]],
      list[:children].first[:children].map { [it[:type], it[:name]] }
    )
    assert_equal(["li"], list[:children].first[:children].first[:children].map { it[:name] })
  end

  def test_element_ids_are_dom_ids
    engine = build_engine(H[:body, H[List]])
    dom_ids = []
    collect_ids(engine.dom_id_tree, dom_ids)

    tree = Mayu::Devtools::Inspector.new.call(engine, {type: "tree"})
    element_ids = []
    each_node(tree) { element_ids << it[:id] if it[:type] == "element" }

    assert_empty(element_ids - dom_ids)
    assert_includes(element_ids, find(tree) { it[:name] == "ul" }[:id])
  end

  def test_internal_components_are_marked
    engine = build_engine(H[:body, H[List]])

    tree = Mayu::Devtools::Inspector.new.call(engine, {type: "tree"})
    internal = []
    each_node(tree) { internal << it[:name] if it[:internal] }

    refute_empty(internal)
    refute_includes(internal, "List")
  end

  def test_unknown_queries_are_answered_with_an_error
    engine = build_engine(H[:body])

    assert_equal(
      {error: "Unknown query: {type: \"nope\"}"},
      Mayu::Devtools::Inspector.new.call(engine, {type: "nope"})
    )
  end

  private

  def build_engine(descriptor)
    Mayu::Runtime::Engine.new(descriptor, metrics: Mayu::Test::FakeMetrics.new)
  end

  def each_node(node, &block)
    yield node
    node[:children].each { each_node(it, &block) }
  end

  def find(tree)
    each_node(tree) { return it if yield(it) }
    nil
  end

  def collect_ids(nodes, ids)
    Array(nodes).each do |node|
      ids << node.id
      collect_ids(node.children, ids)
    end
  end
end
