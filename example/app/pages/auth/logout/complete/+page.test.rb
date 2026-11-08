# frozen_string_literal: true

Completion = import("./+page.haml")

def test_logout_completion_broadcasts_before_document_navigation
  screen = render(Completion)
  screen.settle
  actions = screen.commands.grep(Mayu::Runtime::Commands::BrowserAction)
  assert_equal(["reload_other_tabs", "navigate"], actions.map(&:name))
  assert_equal([], actions.first.args)
  assert_equal(["/demos/auth", true, true], actions.last.args)
  assert_equal("/demos/auth", screen.get_by_role(:link, name: "Return to the demo")["href"])
end
