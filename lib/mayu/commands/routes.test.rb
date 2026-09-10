#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "samovar"

require_relative "routes"

class Mayu::Commands::RoutesTest < Minitest::Test
  def test_prints_a_plain_route_tree_when_no_color_is_set
    Dir.mktmpdir("mayu-routes") do |root|
      FileUtils.mkdir_p(File.join(root, "app", "pages"))
      File.write(File.join(root, "app", "pages", "+page.haml"), "%p Hello\n")
      File.write(File.join(root, "app", "pages", "+route.rb"), "def GET = [200, {}, [\"OK\"]]\n")
      File.write(
        File.join(root, "mayu.toml"),
        <<~TOML
          [development]
          secret_key = "dev"

          [development.server]

          [development.metrics]
        TOML
      )

      previous_no_color = ENV["NO_COLOR"]
      ENV["NO_COLOR"] = "1"
      output = Dir.chdir(root) { capture_io { Mayu::Commands::Routes.new([]).call }.first }

      assert_includes(output, "METHOD  PATH  TYPE")
      assert_includes(output, "Route tree")
      assert_includes(output, "GET / (page+handler)")
      refute_includes(output, "\e[")
    ensure
      ENV["NO_COLOR"] = previous_no_color
    end
  end
end
