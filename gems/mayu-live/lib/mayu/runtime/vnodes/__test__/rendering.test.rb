#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::RenderingTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

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

  def test_omits_an_empty_inline_style_attribute
    engine =
      Mayu::Runtime::Engine.new(
        H[:body, style: {color_scheme: nil, display: false}],
        metrics: NullMetrics.new
      )

    refute_includes(render_html(engine.root), "<body style=")
  end

  def test_normalizes_nested_class_names
    engine =
      Mayu::Runtime::Engine.new(
        H[
          :body,
          H[
            :p,
            "Classes",
            class: [:button, ["primary large", nil, [:icon]], :button]
          ]
        ],
        metrics: NullMetrics.new
      )

    assert_includes(
      render_html(engine.root),
      '<p class="button primary large icon button">Classes</p>'
    )
  end

  def test_ignores_false_class_names
    engine =
      Mayu::Runtime::Engine.new(
        H[:body, H[:p, "Classes", class: [false, [:button, false]]]],
        metrics: NullMetrics.new
      )

    html = render_html(engine.root)
    assert_includes(html, '<p class="button">Classes</p>')
    refute_includes(html, "false")
  end

  def test_flattens_nested_props_without_flattening_inline_styles
    attributes = Mayu::Runtime::VNodes::VAttributes.allocate
    style = {color: "red", hover: {color: "blue"}}

    flattened =
      attributes.send(
        :flatten_props,
        {
          id: "probe",
          data: {controller: {action: "save"}, active: true},
          aria: {label: "Save"},
          style:
        }
      )

    assert_equal(
      {
        id: "probe",
        "data-controller-action": "save",
        "data-active": true,
        "aria-label": "Save",
        style:
      },
      flattened
    )
    assert_same(style, flattened[:style])
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
