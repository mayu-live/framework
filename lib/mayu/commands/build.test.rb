#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "samovar"

require_relative "build"

class Mayu::Commands::BuildTest < Minitest::Test
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

      Dir.chdir(root) do
        Mayu::Commands::Build.new([]).call
      end

      assert_path_exists(File.join(root, "app.mayu-bundle"))
    ensure
      ENV["MAYU_SECRET_KEY"] = previous_secret_key if previous_secret_key
    end
  end
end
