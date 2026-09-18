#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "tmpdir"
require "fileutils"

require_relative "environment"
require "mayu/build"

class Mayu::EnvironmentTest < Minitest::Test
  def test_missing_client_runtime_explains_how_to_build_it
    missing_path = File.join(Dir.mktmpdir("mayu-runtime"), "entries.json")

    error = assert_raises(RuntimeError) do
      Mayu::Environment.stub(:client_runtime_entries_path, missing_path) do
        Mayu::Environment.ensure_client_runtime!
      end
    end

    assert_includes(error.message, missing_path)
    assert_includes(error.message, "npm run build")
  end

  def test_load_klenod_with_config_uses_runtime_provider_without_legacy_state
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "entry.rb"), "VALUE = 42\n")

      bundle_path = File.join(root, "app.mayu-bundle")
      Mayu::Build::Configuration.new(root:, entrypoints: ["entry"]).build(
        output: bundle_path
      )

      environment =
        Mayu::Environment.load_klenod_with_config(
          config(root),
          bundle_path,
          metrics: Object.new
        )

      assert_equal(42, environment.module_provider.exports("entry")::VALUE)
      assert_equal(environment, environment.use { it })
    end
  end

  def test_the_runtime_provider_preloads_every_module_in_the_bundle
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "entry.rb"), "VALUE = 42\n")

      bundle_path = File.join(root, "app.mayu-bundle")
      Mayu::Build::Configuration.new(root:, entrypoints: ["entry"]).build(
        output: bundle_path
      )

      provider = Mayu::Environment.load_klenod_provider(config(root), bundle_path)
      mods = provider.preload

      refute_empty(mods)
      assert(mods.all? { it.const_defined?(:Exports) })
      assert_equal(42, provider.exports("entry")::VALUE)
    end
  end

  def test_environment_requires_a_module_provider
    assert_raises(ArgumentError) do
      Mayu::Environment.new(config(Dir.mktmpdir("mayu-klenod")), metrics: Object.new)
    end
  end

  def test_start_hooks_run_with_the_app_and_stop_what_they_returned
    environment =
      Mayu::Environment.new(
        config(Dir.mktmpdir("mayu-klenod")),
        module_provider: Object.new,
        metrics: Object.new
      )
    stoppable = Struct.new(:stopped) { def stop = self.stopped = true }.new(false)
    seen = []
    environment.on_start { |app| seen << app }
    environment.on_start { |_app| stoppable }

    environment.start(:app)
    environment.stop

    assert_equal([:app], seen)
    assert(stoppable.stopped)
  end

  private

  def config(root)
    server =
      Mayu::Configuration::ServerConfig.new(
        listen: "http://localhost:3000",
        hmr?: false,
        render_exceptions?: false,
        self_signed_cert?: false,
        generate_assets?: false,
        session_timeout_seconds: 10,
        transfer_timeout_seconds: 10,
        shutdown_timeout_seconds: 10,
        cookie_timeout_seconds: 10
      )
    metrics =
      Mayu::Configuration::MetricsConfig.new(enabled?: false, listen: nil)

    Mayu::Configuration::Config.new(
      root:,
      secret_key: "secret",
      server:,
      metrics:
    )
  end
end
