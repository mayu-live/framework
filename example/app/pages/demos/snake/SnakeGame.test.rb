# frozen_string_literal: true

SnakeGame = import("./SnakeGame.haml")

def test_does_not_chain_turns_before_the_next_tick
  screen = render(SnakeGame)
  game = snake_game_instance(screen)

  game.handle_turn_up
  game.handle_turn_left

  assert_equal([0, -1], state(game, :@queued_direction))

  game.handle_tick

  assert_equal([0, -1], state(game, :@direction))
  assert_equal([16, 7], state(game, :@snake).first)
end

def state(component, name)
  component.instance_variable_get(:@__state)[name.to_s.delete_prefix("@").to_sym]
end

def snake_game_instance(screen)
  engine = screen.instance_variable_get(:@engine)

  engine.root.send(:traverse) do |node|
    next unless node.is_a?(Mayu::Runtime::VNodes::VComponent)

    instance = node.instance_variable_get(:@instance)
    return instance if instance.is_a?(SnakeGame)
  end

  raise "Could not find the SnakeGame component"
end
