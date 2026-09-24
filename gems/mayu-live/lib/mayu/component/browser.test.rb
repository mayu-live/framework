# frozen_string_literal: true

require "minitest/autorun"

require_relative "base"

class Mayu::Component::BrowserTest < Minitest::Test
  def setup
    @actions = []
    @browser =
      Mayu::Component::Browser.new(->(name, args) { @actions << [name, args] })
  end

  def test_navigate_pushes_by_default
    @browser.navigate("?page=2")

    assert_equal([["navigate", ["?page=2", false]]], @actions)
  end

  def test_navigate_can_replace_the_history_entry
    @browser.navigate("/demos", replace: true)

    assert_equal([["navigate", ["/demos", true]]], @actions)
  end

  def test_navigate_requires_a_string_href
    assert_raises(ArgumentError) { @browser.navigate(:demos) }
    assert_empty(@actions)
  end

  def test_alert_sends_the_message_as_a_string
    @browser.alert(42)

    assert_equal([["alert", ["42"]]], @actions)
  end

  def test_unmounted_components_cannot_use_browser_actions
    component = Mayu::Component::Base.new

    error = assert_raises(RuntimeError) { component.send(:browser).alert("hi") }
    assert_match(/browser\.alert can only be called once the component is mounted/, error.message)
  end
end
