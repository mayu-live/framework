#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes2::RenderingTest < Minitest::Test
  include Mayu::Runtime::VNodes2::TestHelpers

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

    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
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

  def test_component_renders_html
    descriptor = H[:body, H[RenderProbe]]

    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    html = render_html(engine.root)

    assert_match(
      "<section><h2>Rendered</h2><p>From component</p></section>",
      html
    )
  end

  def test_dom_id_tree_structure
    descriptor =
      H[:body, H[:header, H[:h1, "Title"]], H[:main, H[:p, "Content"]]]

    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    tree = engine.dom_id_tree

    assert_equal("#document", tree.name)
    assert_equal("HTML", tree.children.first.name)

    html_node = tree.children.first
    body_node = html_node.children.find { |node| node.name == "BODY" }

    refute_nil(body_node)
    assert(body_node.children.any? { |node| node.name == "HEADER" })
    assert(body_node.children.any? { |node| node.name == "MAIN" })
  end
end
