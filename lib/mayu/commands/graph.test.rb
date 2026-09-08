#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "fileutils"

require_relative "../klenod"
require_relative "../commands"

class Mayu::Commands::GraphTest < Minitest::Test
  def test_exports_a_mayu_bundle_as_graphviz_dot
    Dir.mktmpdir("mayu-graph") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "root.haml"), "%p Hello\n")
      bundle_path = File.join(root, "app.mayu-bundle")

      Mayu::Klenod::Configuration.new(root:).build(output: bundle_path)

      output = StringIO.new
      Mayu::Commands::Application.new(["graph", bundle_path], output:).call

      assert(output.string.start_with?("digraph klenod"))
    end
  end

  def test_uses_mayu_in_its_description
    assert_equal(
      "Export a Mayu runtime bundle as Graphviz DOT.",
      Mayu::Commands::Graph.description
    )
  end
end
