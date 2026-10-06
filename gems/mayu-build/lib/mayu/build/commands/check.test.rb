#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "fileutils"

require_relative "../../build"
require_relative "../cli"

class Mayu::Build::Commands::CheckTest < Minitest::Test
  def test_reports_missing_mayu_toml
    Dir.mktmpdir("mayu-check") do |dir|
      output = StringIO.new

      status = Dir.chdir(dir) { Mayu::Build::Commands::Check.new([], output:).call }

      assert_equal(1, status)
      assert_match(/Could not find mayu\.toml/, output.string)
    end
  end

  def test_reports_diagnostics_relative_to_the_working_directory
    with_app do |root|
      File.write(File.join(root, "app", "pages", "broken.haml"), ":ruby\n  Missing = import(\"/components/Missing\")\n%Missing\n")
      output = StringIO.new

      status = Dir.chdir(File.join(root, "app")) { Mayu::Build::Commands::Check.new([], output:).call }

      assert_equal(1, status)
      assert_match(%r{^pages/broken\.haml\n  2:\d+  error  .*/components/Missing}, output.string)
      assert_match(/^1 error, 2 files checked\.$/, output.string)
    end
  end

  def test_checks_only_the_given_paths
    with_app do |root|
      File.write(File.join(root, "app", "pages", "broken.haml"), ":ruby\n  Missing = import(\"/components/Missing\")\n%Missing\n")
      output = StringIO.new

      status = Dir.chdir(root) { Mayu::Build::Commands::Check.new(["app/root.haml"], output:).call }

      assert_equal(0, status)
      assert_equal("No problems found, 1 file checked.\n", output.string)
    end
  end

  def test_rejects_missing_paths
    with_app do |root|
      output = StringIO.new

      status = Dir.chdir(root) { Mayu::Build::Commands::Check.new(["app/nope.haml"], output:).call }

      assert_equal(1, status)
      assert_equal("No such file or directory: app/nope.haml\n", output.string)
    end
  end

  def test_application_lists_the_command
    output = StringIO.new

    Mayu::Build::CLI::Application.new([], output:).call

    assert_match(/check <paths\.\.\.>/, output.string)
  end

  private

  def with_app
    Dir.mktmpdir("mayu-check") do |tmpdir|
      root = File.realpath(tmpdir)
      File.write(File.join(root, "mayu.toml"), "[development]\n")
      FileUtils.mkdir_p(File.join(root, "app", "pages"))
      File.write(File.join(root, "app", "root.haml"), "%p Hello\n")

      yield root
    end
  end
end
