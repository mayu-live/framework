# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::AttributeNamesTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  def build(element)
    Mayu::Runtime::Engine.new(H[:body, element], metrics: NullMetrics.new)
  end

  def update(element, descriptor)
    collector = Mayu::Runtime::VNodes::CommandCollector.new
    element.update(collector, descriptor)
    collector.commands
  end

  def test_attribute_commands_carry_the_html_name
    engine = build(H[:button, "Send"])
    button = find_element(engine.root, :button)

    assert_equal(
      [
        Mayu::Runtime::Commands::SetAttribute[button.dom_id, "aria-label", "Send message"],
        Mayu::Runtime::Commands::SetAttribute[button.dom_id, "data-user-id", "7"]
      ],
      update(button, H[:button, "Send", aria_label: "Send message", data_user_id: 7])
    )
    assert_equal(
      [Mayu::Runtime::Commands::RemoveAttribute[button.dom_id, "aria-label"]],
      update(button, H[:button, "Send", data_user_id: 7])
    )
  end

  def test_the_rendered_html_uses_the_same_names
    engine = build(H[:button, "Send", aria_label: "Send message"])

    assert_includes(render_html(engine.root), %(<button aria-label="Send message">))
  end

  def test_initial_value_keeps_its_name
    engine = build(H[:input, initial_value: "a"])
    input = find_element(engine.root, :input)

    assert_equal(
      [Mayu::Runtime::Commands::SetAttribute[input.dom_id, :initial_value, "b"]],
      update(input, H[:input, initial_value: "b"])
    )
  end
end
