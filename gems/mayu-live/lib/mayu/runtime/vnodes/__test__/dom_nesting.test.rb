#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"
require "console"
require "stringio"

class Mayu::Runtime::VNodes::DOMNestingTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class ElementInTitle < Mayu::Component::Base
    def render
      H[:head, H[:title, "foo", H[:span, "bar"], "baz"]]
    end
  end

  class DivInParagraph < Mayu::Component::Base
    def render
      H[:p, H[:div, @__props[:text]]]
    end
  end

  class ValidPage < Mayu::Component::Base
    def render
      [
        H[:head, H[:title, "Page"], H[:meta, name: "viewport", content: "width=device-width"]],
        H[:main, H[:ul, H[:li, H[:a, "link", href: "/"]]], H[:table, H[:tbody, H[:tr, H[:td, "cell"]]]]]
      ]
    end
  end

  def test_warns_about_elements_inside_a_title
    output = capture_warnings { build_engine(H[:body, H[ElementInTitle]]) }

    assert_includes(output, "Invalid DOM nesting")
    assert_includes(output, "In HTML, <span> can not be a child of <title>.")
    # Invalid elements get lines of their own.
    assert_match(/%head\n.*%title\n.*%span\n/, output)
  end

  def test_warns_about_invalid_descendants
    output = capture_warnings { build_engine(H[:body, H[DivInParagraph, text: "a"]]) }

    assert_includes(output, "In HTML, <div> can not be a descendant of <p>.")
    assert_match(/%p\n.*%div\n/, output)
  end

  def test_marks_the_element_and_the_ancestor_it_can_not_be_in
    event =
      Mayu::Runtime::DOMNestingWarningEvent.for(
        nil,
        message: "In HTML, <span> can not be a child of <title>.",
        tree_path: [{name: "title"}, {name: "head"}, {name: "title"}, {name: "span"}],
        invalid_tag: :title
      )

    assert_equal(
      [nil, nil, true, true],
      event.to_hash[:tree_path].map { it[:invalid] }
    )
  end

  def test_warns_once_per_component_and_message
    output =
      capture_warnings do
        engine = build_engine(H[:body, H[DivInParagraph, text: "a"]])
        engine.update(H[:body, H[DivInParagraph, text: "b"]])
        engine.update(H[:body, H[:section, H[DivInParagraph, text: "c"]]])
      end

    # The last update replaces the component, so it warns once more.
    assert_equal(2, output.scan("can not be a descendant of <p>").length)
  end

  def test_a_valid_document_does_not_warn
    output =
      capture_warnings do
        engine =
          build_engine(
            H[:body, H[ValidPage]],
            runtime_js: "/.mayu/runtime/init.js",
            stylesheets: ["/.mayu/assets/page.css"]
          )
        render_html(engine.root)
      end

    assert_empty(output)
  end

  def test_validation_is_off_by_default
    output =
      capture_warnings do
        Mayu::Runtime::Engine.new(H[:body, H[ElementInTitle], H[DivInParagraph]], metrics: NullMetrics.new)
      end

    assert_empty(output)
  end

  private

  def build_engine(descriptor, **)
    Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new, validate_dom_nesting: true, **)
  end

  def capture_warnings
    output = StringIO.new
    previous_logger = Console.logger
    Console.logger = Console::Logger.new(Console::Output::Text.new(output))
    yield
    output.string
  ensure
    Console.logger = previous_logger
  end
end
