#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require_relative "test"

class Mayu::Test::Test < Mayu::Test::Case
  H = Mayu::Runtime::H

  class Counter < Mayu::Component::Base
    def initialize
      @count = 0
    end

    def increment
      update!(@count += 1)
    end

    def render
      H[
        :section,
        H[:output, @count],
        H[:button, "Increment", onclick: H.callback(self, :increment)]
      ]
    end
  end

  class InputMirror < Mayu::Component::Base
    def initialize
      @value = ""
    end

    def change(event)
      update!(@value = event.dig(:currentTarget, :value))
    end

    def render
      H[
        :label,
        "Message",
        H[:input, value: @value, oninput: H.callback(self, :change)],
        H[:output, @value]
      ]
    end
  end

  def test_queries_roles_text_css_and_scoped_content
    screen =
      render(
        H[
          :main,
          H[:h2, "Settings"],
          H[:section, H[:button, "Save"], id: "actions"],
          H[:section, H[:button, "Save"], id: "dialog"],
          H[:p, "Saved ", H[:strong, "successfully"]],
          H[:button, "Hidden", hidden: true]
        ]
      )

    assert_equal("h2", screen.get_by_role(:heading, name: "Settings").name)
    assert_equal("strong", screen.get_by_text(/success/).name)
    assert_equal("main", screen.get_by_css("main").name)
    assert_equal(2, screen.get_all_by_role(:button, name: "Save").length)
    assert_nil(screen.query_by_role(:button, name: "Missing"))
    refute(screen.has_text?("Hidden"))

    actions = screen.within(screen.get_by_css("#actions"))
    assert_equal("Save", actions.get_by_role(:button).text)
    assert_nil(actions.query_by_css("#dialog"))
  end

  def test_queries_accessible_names
    screen =
      render(
        H[
          :main,
          H[:label, "Email address", for: "email"],
          H[:input, id: "email", type: "email"],
          H[
            :button,
            H[:span, "Icon", aria_hidden: true],
            aria_label: "Save changes"
          ],
          H[:img, src: "portrait.jpg", alt: "Portrait of Ada"]
        ]
      )

    assert_equal(
      "email",
      screen.get_by_role(:textbox, name: "Email address")["type"]
    )
    assert_equal(
      "Save changes",
      screen.get_by_role(:button, name: "Save changes")["aria-label"]
    )
    assert_equal(
      "portrait.jpg",
      screen.get_by_role(:img, name: /Ada/)["src"]
    )
  end

  def test_strict_queries_report_ambiguity_and_current_html
    screen = render(H[:main, H[:button, "Save"], H[:button, "Cancel"]])

    error = assert_raises(Mayu::Test::QueryError) do
      screen.get_by_role(:button)
    end

    assert_includes(error.message, "Found 2 matches; expected exactly one")
    assert_includes(error.message, "Candidates:")
    assert_includes(error.message, "Rendered HTML:")
    assert_includes(error.message, "<button>Cancel</button>")
  end

  def test_click_settles_component_updates
    screen = render(Counter)

    screen.get_by_role(:button, name: "Increment").click

    assert_equal("1", screen.get_by_role(:status).text)
  end

  def test_input_and_type_settle_component_updates
    screen = render(InputMirror)
    input = screen.get_by_role(:textbox, name: "Message")

    input.input("Hello")
    assert_equal("Hello", screen.get_by_role(:status).text)

    input.type("!")
    assert_equal("Hello!", screen.get_by_role(:status).text)
  end

  def test_render_block_remains_supported
    render(H[:p, "Hello"]) do |screen|
      assert_equal("Hello", screen.get_by_text("Hello").text)
    end
  end
end
