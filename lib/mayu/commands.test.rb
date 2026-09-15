#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require_relative "commands"

class Mayu::CommandsTest < Minitest::Test
  def test_placeholder_explains_the_missing_gem_and_fails
    placeholder =
      Mayu::Commands::MissingBuildCommand.define("dev", "Start the development server")
    output = StringIO.new

    status = placeholder.new([], output:).call

    assert_equal(1, status)
    assert_includes(output.string, "dev requires the mayu-build gem")
    assert_includes(placeholder.description, "Start the development server")
    assert_includes(placeholder.description, "requires the mayu-build gem")
  end

  def test_every_build_command_has_a_placeholder_description
    assert_equal(
      Mayu::Commands::ORDER - ["start"],
      Mayu::Commands::BUILD_COMMANDS.keys
    )
  end

  def test_start_is_always_available
    assert_same(Mayu::Commands::Start, Mayu::Commands.commands.fetch("start"))
  end
end
