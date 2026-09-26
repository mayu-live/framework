# frozen_string_literal: true

Page = import("./+page.haml")

def test_renders_silent_haml_examples_and_toggles_a_branch
  screen = render(Page)

  assert_equal(
    "Silent Haml control flow",
    screen.get_by_role(:heading, name: "Silent Haml control flow").text
  )
  assert_equal("1", screen.get_by_text("1").text)

  screen.get_by_role(:button, name: "Toggle if (true)").click

  assert_equal(
    "Toggle if (false)",
    screen.get_by_role(:button, name: "Toggle if (false)").text
  )
end
