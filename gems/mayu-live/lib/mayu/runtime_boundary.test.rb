#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require "rbconfig"

require_relative "build"

# The production server must run on klenod-runtime and klenod-rack alone.
# This builds a bundle here, then renders it in a fresh process and checks
# that nothing from klenod-build or Mayu::Build was needed to do so.
class Mayu::RuntimeBoundaryTest < Minitest::Test
  FIXTURE = File.expand_path("__test__/runtime_boundary.rb", __dir__)

  def test_rendering_a_prebuilt_bundle_loads_no_build_code
    Dir.mktmpdir("mayu-runtime-boundary") do |root|
      FileUtils.mkdir_p(File.join(root, "app", "pages"))
      File.write(File.join(root, "app", "root.haml"), "%slot\n")
      File.write(File.join(root, "app", "pages", "+page.haml"), "%p Runtime only\n")
      bundle = File.join(root, Mayu::Klenod::BUNDLE_FILENAME)
      Mayu::Build::Configuration.new(root:, mode: :production).build(output: bundle)

      output =
        IO.popen(
          [RbConfig.ruby, "-W0", "-rbundler/setup", FIXTURE, root, bundle],
          err: [:child, :out],
          &:read
        )
      assert($?.success?, output)
      report = JSON.parse(output.lines.last)

      assert_includes(report.fetch("html"), "Runtime only")
      refute(report.fetch("klenod_build_defined"), "Klenod::Build was loaded")
      refute(report.fetch("mayu_build_defined"), "Mayu::Build was loaded")
      assert_empty(report.fetch("build_features"))
    end
  end
end
