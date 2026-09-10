#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "samovar"

require_relative "build"

class Mayu::Commands::BuildTest < Minitest::Test
  def test_no_color_disables_ansi_output
    previous_no_color = ENV["NO_COLOR"]
    ENV["NO_COLOR"] = "1"

    command = Mayu::Commands::Build.new([])
    command.define_singleton_method(:interactive?) { true }
    output =
      capture_io do
        command.send(:report_build, :collecting_bundle, entrypoints: ["root.haml"])
      end.first

    refute_includes(output, "\e[")
  ensure
    ENV["NO_COLOR"] = previous_no_color
  end

  def test_build_does_not_require_the_production_secret_key
    Dir.mktmpdir("mayu-build") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "root.haml"), "%p Hello\n")
      File.write(
        File.join(root, "mayu.toml"),
        <<~TOML
          [development]
          secret_key = "dev"

          [development.server]

          [development.metrics]

          [production]
          secret_key = "$MAYU_SECRET_KEY"

          [production.server]

          [production.metrics]
        TOML
      )

      previous_secret_key = ENV.delete("MAYU_SECRET_KEY")

      output =
        Dir.chdir(root) do
          capture_io { Mayu::Commands::Build.new([]).call }.first
        end

      assert_includes(output, "Entrypoints: root.haml, virtual:router")
      assert_includes(output, "Collecting modules: 0")
      refute_includes(output, "\e[")
      assert_includes(output, "Modules")
      assert_includes(output, "Materializing assets")
      assert_includes(output, "Writing bundle")
      assert_match(/Built .* in \d+\.\d{2}s/, output)

      assert_path_exists(File.join(root, "app.mayu-bundle"))
    ensure
      ENV["MAYU_SECRET_KEY"] = previous_secret_key if previous_secret_key
    end
  end
end
