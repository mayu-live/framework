#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require "rbconfig"

require "mayu/build"

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
      File.write(File.join(root, "app", "Identity.rb"), "class Identity; def self.id = 42; end\nDefault = Identity\n")
      File.write(File.join(root, "app", "hooks.rb"), <<~RUBY)
        Identity = import("./Identity.rb")
        def self.prepare_session(request) = {identity_id: Identity.id}
        def self.authorize_session(info) = info[:identity_id] == Identity.id
      RUBY
      bundle = File.join(root, Mayu::Klenod::BUNDLE_FILENAME)
      Mayu::Build::Configuration.new(root:, mode: :build).build(output: bundle)
      FileUtils.rm_rf(File.join(root, "app"))

      output =
        IO.popen(
          [RbConfig.ruby, "-W0", "-rbundler/setup", FIXTURE, root, bundle],
          err: [:child, :out],
          &:read
        )
      assert($?.success?, output)
      report = JSON.parse(output.lines.last)

      assert_includes(report.fetch("html"), "Runtime only")
      assert_equal({"identity_id" => 42}, report.fetch("prepared_context"))
      refute(report.fetch("klenod_build_defined"), "Klenod::Build was loaded")
      refute(report.fetch("mayu_build_defined"), "Mayu::Build was loaded")
      refute(report.fetch("mayu_devtools_defined"), "Mayu::Devtools was loaded")
      refute(report.fetch("inspector"), "The environment has a devtools inspector")
      assert_equal(["1", nil], report.fetch("inspect_result"))
      assert_empty(report.fetch("build_features"))
    end
  end
end
