#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"

require_relative "cli"

class Mayu::CLITest < Minitest::Test
  def setup
    @previous_no_color = ENV["NO_COLOR"]
    ENV["NO_COLOR"] = "1"
  end

  def teardown
    ENV["NO_COLOR"] = @previous_no_color
  end

  def test_colors_are_used_unless_no_color_is_set
    ENV["NO_COLOR"] = nil
    assert_equal("\e[1mmayu dev\e[0m", Mayu::CLI.color(:bold, "mayu dev"))

    ENV["NO_COLOR"] = "1"
    assert_equal("mayu dev", Mayu::CLI.color(:bold, "mayu dev"))
  end

  def test_hands_everything_to_mayu_build_when_it_is_installed
    seen = nil
    build_cli = Object.new
    build_cli.define_singleton_method(:call) { |argv| seen = argv }

    Mayu::CLI.stub(:build_cli, -> { build_cli }) do
      Mayu::CLI.call(["dev", "--verbose"])
    end

    assert_equal(["dev", "--verbose"], seen)
  end

  def test_build_commands_explain_the_missing_gem
    output = StringIO.new

    status = without_build_gem { Mayu::CLI.call(["dev"], output:) }

    assert_equal(1, status)
    assert_includes(output.string, "mayu dev requires the mayu-build gem")
    assert_includes(output.string, "gem \"mayu-build\", \"= #{Mayu::VERSION}\"")
    assert_includes(output.string, "bundle add mayu-build --version \"= #{Mayu::VERSION}\" --group development,test")
  end

  def test_unknown_commands_print_usage
    output = StringIO.new

    status = without_build_gem { Mayu::CLI.call(["frobnicate"], output:) }

    assert_equal(1, status)
    assert_includes(output.string, "Unknown command: frobnicate")
    assert_includes(output.string, "mayu start")
  end

  def test_help_lists_start_and_the_build_commands
    output = StringIO.new

    status = without_build_gem { Mayu::CLI.call([], output:) }

    assert_equal(0, status)
    assert_includes(output.string, "Mayu v#{Mayu::VERSION}")
    assert_includes(output.string, "mayu start")
    assert_includes(output.string, "Install the mayu-build gem")
  end

  def test_start_parses_its_options_with_the_standard_library
    output = StringIO.new
    seen = nil
    fake_start = ->(**options) {
      seen = options
      0
    }

    status =
      without_build_gem do
        Mayu::CLI.stub(:start, fake_start) do
          Mayu::CLI.call(
            ["start", "--filename", "dist/app.bundle", "--assets-dir", "public"],
            output:
          )
        end
      end

    assert_equal(0, status)
    assert_equal("dist/app.bundle", seen[:filename])
    assert_equal("public", seen[:assets_dir])
    assert_equal(Mayu::Klenod::SOURCE_DIR, seen[:source_root])
  end

  def test_start_rejects_unknown_options
    output = StringIO.new

    status = without_build_gem { Mayu::CLI.call(["start", "--bogus"], output:) }

    assert_equal(1, status)
    assert_includes(output.string, "invalid option: --bogus")
  end

  def test_start_explains_a_missing_bundle
    output = StringIO.new

    status =
      Dir.mktmpdir do |root|
        Dir.chdir(root) do
          Mayu::CLI.start(
            filename: "app.mayu-bundle",
            assets_dir: ".assets",
            source_root: "app",
            output:
          )
        end
      end

    assert_equal(1, status)
    assert_includes(output.string, "Could not find")
    assert_includes(output.string, "mayu build")
  end

  def test_other_load_errors_are_not_mistaken_for_the_missing_gem
    error = LoadError.new("cannot load such file -- klenod/plugin/css")
    error.define_singleton_method(:path) { "klenod/plugin/css" }

    assert_raises(LoadError) do
      Mayu::CLI.stub(:require, ->(_feature) { raise error }) { Mayu::CLI.build_cli }
    end
  end

  private

  def without_build_gem(&)
    Mayu::CLI.stub(:build_cli, nil, &)
  end
end
