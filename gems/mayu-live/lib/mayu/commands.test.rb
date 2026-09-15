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

  def test_build_commands_fall_back_to_placeholders_without_the_gem
    commands =
      without_build_gem("mayu/build/commands") { Mayu::Commands.build_commands }

    assert_equal(Mayu::Commands::BUILD_COMMANDS.keys, commands.keys)
    assert(commands.values.all? { it < Mayu::Commands::MissingBuildCommand })
  end

  def test_other_load_errors_are_not_mistaken_for_the_missing_gem
    assert_raises(LoadError) do
      without_build_gem("klenod/plugin/css") { Mayu::Commands.build_commands }
    end
  end

  def test_start_is_always_available
    assert_same(Mayu::Commands::Start, Mayu::Commands.commands.fetch("start"))
  end

  private

  def without_build_gem(missing_feature, &)
    error = LoadError.new("cannot load such file -- #{missing_feature}")
    error.define_singleton_method(:path) { missing_feature }
    Mayu::Commands.stub(:require, ->(_feature) { raise error }, &)
  end
end
