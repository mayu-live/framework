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

  class ChangeProbe < Mayu::Component::Base
    def initialize
      @checked = false
    end

    def change(event)
      update!(@checked = event.dig(:currentTarget, :checked))
    end

    def render
      H[
        :label,
        "Enabled",
        H[
          :input,
          type: "checkbox",
          checked: @checked,
          onchange: H.callback(self, :change)
        ],
        H[:output, @checked.to_s]
      ]
    end
  end

  class DataRoleProbe < Mayu::Component::Base
    def initialize
      @role = "user"
    end

    def toggle
      update!(@role = "assistant")
    end

    def render
      H[
        :button,
        @role,
        data_role: @role,
        aria_label: @role,
        onclick: H.callback(self, :toggle)
      ]
    end
  end

  class MultiRootProbe < Mayu::Component::Base
    def render
      [H[:p, "One"], H[:p, "Two"]]
    end
  end

  class InsertMultiRootProbe < Mayu::Component::Base
    def initialize
      @shown = false
    end

    def show
      update!(@shown = true)
    end

    def render
      H[
        :main,
        H[:button, "Show", onclick: H.callback(self, :show)],
        (@shown ? H[MultiRootProbe] : nil)
      ]
    end
  end

  class ComponentQueryProbe < Mayu::Component::Base
    def initialize
      @__state[:count] = 1
    end

    def render
      H[:output, @__state[:count].to_s]
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

  def test_fire_event_dispatches_and_settles_dom_events
    screen = render(ChangeProbe)
    checkbox = screen.get_by_css("input[type='checkbox']")

    screen.fire_event(
      :change,
      checkbox,
      currentTarget: {
        checked: true
      }
    )

    assert_equal("true", screen.get_by_role(:status).text)
  end

  def test_attribute_updates_use_html_hyphenated_names
    screen = render(DataRoleProbe)
    button = screen.get_by_role(:button)

    assert_equal("user", button["data-role"])
    assert_nil(button["datarole"])

    button.click

    assert_equal("assistant", button["data-role"])
    assert_equal("assistant", button["aria-label"])
    assert_nil(button["datarole"])
  end

  def test_create_tree_supports_multiple_roots
    screen = render(InsertMultiRootProbe)

    screen.get_by_role(:button, name: "Show").click

    assert_equal(["One", "Two"], screen.get_all_by_css("p").map(&:text))
  end

  def test_component_queries_expose_a_test_handle
    screen = render(H[:main, H[ComponentQueryProbe, label: "Counter"]])

    component = screen.get_component(ComponentQueryProbe)

    assert_equal({label: "Counter"}, component.props)
    assert_equal(1, component.state(:count))
    assert_instance_of(ComponentQueryProbe, component.instance!)
    assert_same(component.instance!, screen.query_component(ComponentQueryProbe).instance!)
    assert_equal([component.instance!], screen.get_all_components(ComponentQueryProbe).map(&:instance!))
  end

  def test_component_queries_report_missing_and_ambiguous_components
    screen = render(H[:main, H[ComponentQueryProbe], H[ComponentQueryProbe]])

    assert_nil(screen.query_component(DataRoleProbe))
    assert_raises(Mayu::Test::ComponentNotFoundError) do
      screen.get_component(DataRoleProbe)
    end
    assert_raises(Mayu::Test::MultipleComponentsFoundError) do
      screen.get_component(ComponentQueryProbe)
    end
    assert_raises(Mayu::Test::MultipleComponentsFoundError) do
      screen.query_component(ComponentQueryProbe)
    end
  end

  def test_fire_event_reports_missing_listeners
    screen = render(H[:button, "Save"])

    error = assert_raises(Mayu::Test::Page::NoListenerError) do
      screen.fire_event(:onclick, screen.get_by_role(:button))
    end

    assert_equal("button does not have a Mayu onclick listener", error.message)
  end

  def test_render_block_remains_supported
    render(H[:p, "Hello"]) do |screen|
      assert_equal("Hello", screen.get_by_text("Hello").text)
    end
  end
end
