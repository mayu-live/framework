# frozen_string_literal: true

ButtonGame = import("./ButtonGame.haml")

def test_updates_the_button_after_a_click
  screen = render(ButtonGame)

  screen.get_by_role(:button, name: "Click me!").click

  assert_equal("Click again!!", screen.get_by_role(:button).text)
end
