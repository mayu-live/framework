# frozen_string_literal: true

Quiz = import("./Quiz.haml")

POKEMON = [
  {id: 1, name: "bulbasaur"},
  {id: 25, name: "pikachu"},
  {id: 122, name: "mr-mime"},
  {id: 152, name: "chikorita"}
]

def submit_guess(screen, guess)
  screen.fire_event(
    :submit,
    screen.get_by_css("form"),
    target: {formData: {guess:}}
  )
end

def test_scores_a_correct_guess
  screen = render(Quiz, pokemon: POKEMON)
  quiz = screen.get_component(Quiz)
  current = quiz.state(:current)

  assert_includes([1, 25, 122], current[:id], "Generation I is the default pool")

  submit_guess(screen, current[:name].upcase)

  assert_equal(:correct, quiz.state(:status))
  assert_equal(20, quiz.state(:score))
  assert_equal(1, quiz.state(:streak))
  assert_equal(1, quiz.state(:best_streak))
end

def test_ignores_punctuation_in_guesses
  screen = render(Quiz, pokemon: [{id: 122, name: "mr-mime"}])
  quiz = screen.get_component(Quiz)

  submit_guess(screen, "Mr. Mime")

  assert_equal(:correct, quiz.state(:status))
end

def test_keeps_guessing_after_a_wrong_guess
  screen = render(Quiz, pokemon: POKEMON)
  quiz = screen.get_component(Quiz)
  wrong = POKEMON.find { it != quiz.state(:current) }

  submit_guess(screen, wrong[:name])

  assert_equal(:guessing, quiz.state(:status))
  assert_equal([wrong[:name]], quiz.state(:wrong_guesses))
  assert_equal(0, quiz.state(:score))
end

def test_reveals_when_time_runs_out_and_resets_the_streak
  screen = render(Quiz, pokemon: POKEMON)
  quiz = screen.get_component(Quiz)
  submit_guess(screen, quiz.state(:current)[:name])
  3.times { quiz.instance!.tick }
  assert_equal(1, quiz.state(:streak))

  20.times { quiz.instance!.tick }

  assert_equal(:timeout, quiz.state(:status))
  assert_equal(0, quiz.state(:streak))
end

def test_starts_the_next_round_after_a_correct_guess
  screen = render(Quiz, pokemon: POKEMON)
  quiz = screen.get_component(Quiz)
  first = quiz.state(:current)

  submit_guess(screen, first[:name])
  3.times { quiz.instance!.tick }

  assert_equal(:guessing, quiz.state(:status))
  refute_equal(first, quiz.state(:current))
end

def test_suggests_prefix_matches_before_substring_matches
  screen = render(Quiz, pokemon: [*POKEMON, {id: 26, name: "raichu"}, {id: 172, name: "pichu"}])
  quiz = screen.get_component(Quiz)

  assert_equal(["pichu", "pikachu", "raichu"].sort, quiz.instance!.suggest("chu").sort)
  assert_equal(["pikachu", "pichu"], quiz.instance!.suggest("pi"))
end
