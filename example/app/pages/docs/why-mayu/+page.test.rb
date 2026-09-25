# frozen_string_literal: true

Page = import("./+page.haml")

def test_shows_the_mayu_version
  screen = render(Page)

  assert_equal(
    "It’s still on version #{::Mayu::VERSION}.",
    screen.get_by_text(/still on version/).text
  )
end
