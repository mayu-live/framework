# frozen_string_literal: true

TodoApp = import("./TodoApp.haml")

def test_manages_todos
  screen = render(TodoApp)

  assert_equal("0 items left", screen.get_by_text("0 items left").text)
  assert_empty(screen.query_all_by_role(:listitem))

  ["Write a test", "Ship the feature"].each do |description|
    screen.fire_event(
      :submit,
      screen.get_by_css("form"),
      target: {
        formData: {
          new_todo: description
        }
      }
    )
  end

  assert_equal(
    ["Ship the feature", "Write a test"],
    screen.get_all_by_role(:listitem).map { it.get_by_css("p").text }
  )
  assert_equal("2 items left", screen.get_by_text("2 items left").text)

  write_test = screen.get_by_text("Write a test")
  checkbox = write_test.at_xpath("../input[@type='checkbox']")
  screen.fire_event(
    :onchange,
    checkbox,
    currentTarget: {
      name: checkbox["name"],
      checked: true
    }
  )

  assert_includes(screen.get_by_text("Write a test")["class"], "completed")
  assert_equal("1 item left", screen.get_by_text("1 item left").text)

  screen.get_by_role(:button, name: "Completed").click

  assert_equal(
    ["Write a test"],
    screen.get_all_by_role(:listitem).map { it.get_by_css("p").text }
  )

  screen.get_by_role(:button, name: "Clear completed").click

  assert_empty(screen.query_all_by_role(:listitem))
  assert_equal("1 item left", screen.get_by_text("1 item left").text)
end
