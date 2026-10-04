# frozen_string_literal: true

SnakeGame = import("./SnakeGame.haml")

def test_does_not_chain_turns_before_the_next_tick
  screen = render(SnakeGame)
  game = screen.get_component(SnakeGame)

  game.instance!.handle_turn_up
  game.instance!.handle_turn_left

  assert_equal([0, -1], game.state(:queued_direction))

  game.instance!.handle_tick

  assert_equal([0, -1], game.state(:direction))
  assert_equal([16, 7], game.state(:snake).first)
end
