# frozen_string_literal: true

Calculator = import("./Calculator.haml")

def press(screen, *names)
  names.each { screen.get_by_role(:button, name: it).click }
end

def display(screen) = screen.get_by_css("output").text
def history(screen) = screen.get_by_css("p").text

def test_evaluates_with_operator_precedence
  screen = render(Calculator)

  assert_equal("0", display(screen))

  press(screen, "2", "Add", "3", "Multiply", "4")
  assert_equal("2+3×4", display(screen))

  press(screen, "Equals")
  assert_equal("2+3×4", history(screen))
  assert_equal("14", display(screen))
end

def test_groups_digits_and_divides_exactly
  screen = render(Calculator)

  press(screen, "3", "8", "6", "7", "0", "Divide", "5", "0", "0", "0", "0", "Equals")

  assert_equal("38,670÷50,000", history(screen))
  assert_equal("0.7734", display(screen))
end

def test_avoids_floating_point_errors
  screen = render(Calculator)

  press(screen, "Decimal point", "1", "Add", "0", "Decimal point", "2", "Equals")

  assert_equal("0.3", display(screen))
end

def test_continues_from_the_result_or_starts_over
  screen = render(Calculator)

  press(screen, "9", "Subtract", "4", "Equals", "Multiply", "3")
  assert_equal("5×3", display(screen))
  assert_equal("", history(screen))

  press(screen, "Equals", "7")
  assert_equal("7", display(screen))
end

def test_replaces_a_trailing_operator
  screen = render(Calculator)

  press(screen, "6", "Add", "Multiply", "Divide", "2", "Equals")

  assert_equal("3", display(screen))
end

def test_toggles_sign
  screen = render(Calculator)

  press(screen, "5", "Toggle sign")
  assert_equal("-5", display(screen))

  press(screen, "Subtract", "Toggle sign", "2")
  assert_equal("-5−-2", display(screen))

  press(screen, "Equals")
  assert_equal("-3", display(screen))
end

def test_percent_is_relative_when_adding_or_subtracting
  screen = render(Calculator)

  press(screen, "1", "0", "0", "Add", "2", "0", "Percent")
  assert_equal("100+20%", display(screen))

  press(screen, "Equals")
  assert_equal("100+20%", history(screen))
  assert_equal("120", display(screen))

  press(screen, "All clear", "2", "0", "0", "Subtract", "1", "0", "Percent", "Equals")
  assert_equal("180", display(screen))
end

def test_percent_is_a_fraction_when_multiplying_or_standing_alone
  screen = render(Calculator)

  press(screen, "5", "0", "Multiply", "2", "0", "Percent", "Equals")
  assert_equal("10", display(screen))

  press(screen, "Percent")
  assert_equal("10%", display(screen))

  press(screen, "5", "Decimal point")
  assert_equal("10%", display(screen))

  press(screen, "Equals")
  assert_equal("0.1", display(screen))
end

def test_backspace_and_all_clear
  screen = render(Calculator)

  press(screen, "1", "2", "Add", "Backspace", "Backspace")
  assert_equal("1", display(screen))

  press(screen, "All clear")
  assert_equal("0", display(screen))
end

def test_division_by_zero_shows_an_error
  screen = render(Calculator)

  press(screen, "1", "Divide", "0", "Equals")
  assert_equal("Error", display(screen))
  assert_equal("1÷0", history(screen))

  press(screen, "4")
  assert_equal("4", display(screen))
end

def test_accepts_keyboard_input
  screen = render(Calculator)
  calculator = screen.get_by_css("[tabindex]")

  %w[1 0 * 3 Backspace 4 Enter].each do |key|
    screen.fire_event(:keydown, calculator, key:)
  end

  assert_equal("40", display(screen))
end
