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

  class Sourced < Mayu::Component::Base
    def self.module_path = "/src/app/components/Sourced.haml"

    def render
      H[:p, "sourced"]
    end
  end

  class Unresolved < Mayu::Component::Base
    def self.module_path = "/elsewhere/Unresolved.haml"

    def render
      H[:p, "unresolved"]
    end
  end

  class FakeProvider
    def module_id_for(path)
      raise KeyError, path unless path.start_with?("/src/")
      "app:/#{path.delete_prefix("/src/app/")}"
    end
  end

  def test_paths_are_klenod_module_ids_when_the_provider_knows_them
    engine = build_engine(H[:body, H[Sourced], H[Unresolved]])
    engine.module_provider = FakeProvider.new

    tree = Mayu::Devtools::Inspector.new.call(engine, {type: "tree"})

    assert_equal("app:/components/Sourced.haml", find(tree) { it[:name] == "Sourced" }[:path])
    assert_equal("/elsewhere/Unresolved.haml", find(tree) { it[:name] == "Unresolved" }[:path])
    html = find(tree) { it[:name] == "Html" }
    assert(html[:path].start_with?("(internal)::"))
  end

  def test_paths_stay_paths_without_a_provider
    engine = build_engine(H[:body, H[Sourced]])

    tree = Mayu::Devtools::Inspector.new.call(engine, {type: "tree"})

    assert_equal("/src/app/components/Sourced.haml", find(tree) { it[:name] == "Sourced" }[:path])
  end

  # Stands in for the ClassNames Klenod generates for a component's styles.
  class FakeClassNames
    def initialize(classes) = @classes = classes

    def each_pair(&) = @classes.each_pair(&)
  end

  class Card < Mayu::Component::Base
    ClassNames = FakeClassNames.new({card: "Card_card_1", body: "Card_body_2 shared", __div: "Card_div_4"})

    def render
      H[:div, H[:slot], class: "Card_div_4 Card_card_1 literal"]
    end
  end

  class Page < Mayu::Component::Base
    ClassNames = FakeClassNames.new({title: "Page_title_3"})

    def render
      H[Card, H[:h1, "Hi", class: "Page_title_3"]]
    end
  end

  def test_element_classes_are_named_as_in_the_source
    engine = build_engine(H[:body, H[Page]])

    tree = Mayu::Devtools::Inspector.new.call(engine, {type: "tree"})
    div = find(tree) { it[:name] == "div" }
    h1 = find(tree) { it[:name] == "h1" }

    assert_equal(
      [
        {source: nil, rendered: "Card_div_4", scope: true},
        {source: "card", rendered: "Card_card_1", scope: false},
        {source: nil, rendered: "literal", scope: false}
      ],
      div[:classes]
    )
    # Slotted content is written in Page, not in the Card that renders it.
    assert_equal([{source: "title", rendered: "Page_title_3", scope: false}], h1[:classes])
  end

  def test_elements_without_classes_have_none
    engine = build_engine(H[:body, H[List]])

    tree = Mayu::Devtools::Inspector.new.call(engine, {type: "tree"})

    assert_equal([], find(tree) { it[:name] == "ul" }[:classes])
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
