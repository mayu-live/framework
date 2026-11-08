# frozen_string_literal: true

Dialog = import("./Dialog")
DialogButton = import("./DialogButton")

def test_dialog_button_opens_the_dialog_and_publishes_an_anchor
  render(DialogButton, dialog: "confirm", title: "Delete")

  button = find!(:button)
  assert_equal "show-modal", button[:command]
  assert_equal "confirm", button[:commandfor]
  assert_equal "anchor-name:--dialog-confirm;", button[:style]
end

def test_anchored_dialog_positions_itself_by_the_button
  render(Dialog, id: "confirm", class: "page", anchored: true)

  dialog = find!(:dialog)
  assert_equal "confirm", dialog[:id]
  assert_includes dialog[:class].split, "page"
  assert_match(/\banchored\b/, dialog[:class])
  assert_equal "position-anchor:--dialog-confirm;", dialog[:style]
end

def test_dialog_is_centered_by_default
  render(Dialog, id: "confirm", class: "page")

  dialog = find!(:dialog)
  assert_includes dialog[:class].split, "page"
  refute_match(/\banchored\b/, dialog[:class])
  assert_nil dialog[:style]
end
