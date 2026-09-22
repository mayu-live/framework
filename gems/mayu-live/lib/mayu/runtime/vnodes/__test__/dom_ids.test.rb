#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require "msgpack"

require_relative "test_helpers"

class Mayu::Runtime::VNodes::DomIdsTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  # Renders an array, so it contributes several nodes to its parent.
  class Pair < Mayu::Component::Base
    def render
      [H[:span, "one"], "two", H[:i, "three"]]
    end
  end

  class Wrapper < Mayu::Component::Base
    def render
      H.context(theme: "dark") { [H[:head, H[:title, "T"]], H[Pair], H[:b, "four"]] }
    end
  end

  def test_dom_ids_are_the_top_level_ids_of_the_id_tree
    descriptor =
      H[:body, H[Wrapper], H[:p, H[:em, "nested"]], "text", H[Pair]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    body = nil
    engine.root.send(:traverse) do |node|
      body ||= node if node.is_a?(Mayu::Runtime::VNodes::VElement) && node.tag_name == "body"
    end
    children = body.instance_variable_get(:@children)

    ids = children.dom_ids

    assert_equal(top_level_ids(children.dom_id_tree), ids)
    # Wrapper contributes span, text, i and b (the head contributes nothing),
    # then p, text, Pair again, and the ping element the body injects.
    assert_equal(10, ids.length)
    assert_equal(ids.uniq, ids)
  end

  def test_vnode_ids_are_compact_unique_frozen_strings
    descriptor = H[:body, H[:p, "One"], H[:p, "Two"]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    other_engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    ids = [engine.root.id]

    engine.root.send(:traverse) { |node| ids << node.id }

    assert_equal("v1", engine.root.id)
    assert_equal("v1", other_engine.root.id)
    assert_equal(ids.uniq, ids)
    assert(ids.all? { it.match?(/\Av[0-9a-z]+\z/) })
    assert(ids.all?(&:frozen?))
  end

  def test_id_tree_is_nested_like_the_dom_with_no_arrays_or_nils
    descriptor = H[:body, H[Wrapper], H[:p, H[:em, "nested"]], "text", H[Pair]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

    tree = engine.dom_id_tree

    assert_equal("#document", tree.name)
    assert_well_formed(tree)
    assert_equal(top_level_ids(tree.children), tree.children.map(&:id))
  end

  def test_writing_html_with_id_tree_matches_plain_html_and_yields_one_node
    descriptor = H[:body, H[:p, H[Pair], H[:br], "text"]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    body = nil
    engine.root.send(:traverse) do |node|
      body ||= node if node.is_a?(Mayu::Runtime::VNodes::VElement) && node.tag_name == "body"
    end

    plain = +""
    body.write_html(plain)
    html = +""
    ids = []
    body.write_html_with_id_tree(html, ids)

    assert_equal(plain, html)
    assert_equal(1, ids.length)
    assert_equal("BODY", ids.first.name)
    assert_well_formed(ids.first)
    assert_equal(body.dom_id_tree, ids)
  end

  def test_msgpack_matches_the_serialized_form
    descriptor = H[:body, H[Wrapper], H[:p, "text", H[:br]]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    tree = engine.dom_id_tree

    assert_equal(MessagePack.pack(tree.serialize), MessagePack.pack(tree))
    assert_equal(tree.serialize, MessagePack.unpack(MessagePack.pack(tree), symbolize_keys: true))
  end

  private

  # The previous implementation: flatten the deep tree and keep each root id.
  def assert_well_formed(node)
    assert_kind_of(Mayu::Runtime::DOM::IdNode, node)
    children = node.children
    return if children.nil?

    assert_kind_of(Array, children)
    children.each { |child| assert_well_formed(child) }
  end

  def top_level_ids(tree)
    case tree
    when Array then tree.flat_map { top_level_ids(it) }
    when Mayu::Runtime::DOM::IdNode then [tree.id]
    else []
    end
  end
end
