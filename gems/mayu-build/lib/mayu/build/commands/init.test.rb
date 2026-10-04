#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "samovar"

require_relative "init"

class Mayu::Build::Commands::InitTest < Minitest::Test
  TEMPLATE_SETTLED = File.join(__dir__, "init", "template", "app", "lib", "settled.ts")
  RUNTIME_SETTLED =
    File.expand_path("../../../../../mayu-live/lib/mayu/client/src/settled.ts", __dir__)

  # The app's `settled` helper finds the runtime's promises through a global
  # symbol, so both have to name the same one.
  def test_the_settled_helper_uses_the_runtime_symbol
    symbol = 'Symbol.for("mayu.settled")'

    assert_includes(File.read(RUNTIME_SETTLED), symbol)
    assert_includes(File.read(TEMPLATE_SETTLED), symbol)
  end
end
