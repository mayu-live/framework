#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

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

  private

  # The previous implementation: flatten the deep tree and keep each root id.
  def top_level_ids(tree)
    case tree
    when Array then tree.flat_map { top_level_ids(it) }
    when Mayu::Runtime::DOM::IdNode then [tree.id]
    else []
    end
  end
end
