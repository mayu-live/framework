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

  def test_client_runtime_manifest_identifies_the_hashed_initializer
    Dir.mktmpdir("mayu-runtime") do |root|
      entries_path = File.join(root, "entries.json")
      File.write(entries_path, '{"init":"init-abc123.js"}')
      File.write(File.join(root, "init-abc123.js"), "")

      Mayu::Environment.stub(:client_runtime_entries_path, entries_path) do
        assert_equal("init-abc123.js", Mayu::Environment.ensure_client_runtime!)
      end
    end
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

    assert_match(%r{\A/.mayu/runtime/init-[\w-]+\.js\z}, environment.runtime_init_js_path)
    assert_equal([:app], seen)
    assert(stoppable.stopped)
  end

  def test_application_hooks_import_the_same_identity_as_other_modules
    with_hooks(<<~RUBY) do |environment, _root, provider|
      Identity = import("./Identity.rb")

      def self.prepare_session(request)
        {identity_id: Identity.id, request: request}
      end

      def self.authorize_session(session, phase:, request: nil)
        session == Identity.id && phase == :event && request.nil?
      end
    RUBY
      environment.prepare_session { flunk "application hook takes precedence" }
      environment.authorize_session { flunk "application hook takes precedence" }
      assert_equal({identity_id: 42, request: "request"}, environment.prepare_session_for("request").context)
      assert_nil(environment.authorize_session!(42, phase: :event))
      assert_raises(Mayu::Session::Rejected) { environment.authorize_session!(41, phase: :event) }
      hooks = provider.application_hooks
      assert_same(provider.exports(provider.entry("Identity.rb"))::Identity, hooks::Identity)
    end
  end

  def test_application_authorizer_filters_keywords_and_requires_true
    ["def self.authorize_session(session) = session", "def self.authorize_session(session, **metadata) = session && metadata[:phase] == :event"].each do |source|
      with_hooks(source) do |environment|
        assert_nil(environment.authorize_session!(true, phase: :event))
        assert_raises(Mayu::Session::Rejected) { environment.authorize_session!(nil, phase: :event) }
      end
    end
  end

  def test_application_preparation_preserves_responses_and_headers
    with_hooks(<<~RUBY) do |environment|
      def self.prepare_session(request)
        return Mayu::Session::Preparation.redirect("/login") if request == :redirect
        Mayu::Session::Preparation.new(context: {id: 42}, headers: [["set-cookie", "identity=42"]])
      end
    RUBY
      assert_equal([["set-cookie", "identity=42"]], environment.prepare_session_for(nil).headers)
      assert_equal("/login", environment.prepare_session_for(:redirect).headers["location"])
    end
  end

  def test_application_wrapper_runs_inside_registered_wrappers
    with_hooks(<<~RUBY) do |environment|
      def self.around_request(request, next_app)
        request << :application
        next_app.call(request).tap { request << :after_application }
      end
    RUBY
      environment.around_request do |request, next_app|
        request << :registered
        next_app.call(request).tap { request << :after_registered }
      end
      calls = []
      assert_equal(:response, environment.wrap_request(calls) {
        calls << :dispatch
        :response
      })
      assert_equal(%i[registered application dispatch after_application after_registered], calls)
    end
  end

  def test_application_wrapper_can_short_circuit_and_cannot_call_continuation_twice
    with_hooks(<<~RUBY) do |environment|
      def self.around_request(request, next_app)
        return :response if request == :short_circuit
        next_app.call(request)
        next_app.call(request)
      end
    RUBY
      assert_equal(:response, environment.wrap_request(:short_circuit) { flunk "must not dispatch" })
      assert_raises(RuntimeError) { environment.wrap_request(nil) { :response } }
    end
  end

  def test_missing_application_hooks_and_methods_preserve_registered_defaults
    [nil, "VALUE = 1"].each do |source|
      with_hooks(source) do |environment|
        assert_equal({}, environment.prepare_session_for(nil).context)
        assert_nil(environment.authorize_session!(nil, phase: :start))
        environment.prepare_session { |_| {id: 42} }
        environment.authorize_session { |_| false }
        assert_equal({id: 42}, environment.prepare_session_for(nil).context)
        assert_raises(Mayu::Session::Rejected) { environment.authorize_session!(nil, phase: :start) }
      end
    end
  end

  def test_broken_hook_imports_fail_startup
    assert_raises(::Klenod::Build::ResolveError) do
      with_hooks('Identity = import("./Missing.rb")') { flunk "must not start" }
    end
  end

  private

  def with_hooks(source)
    Dir.mktmpdir("mayu-hooks") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "hooks.rb"), source) if source
      File.write(File.join(root, "app", "Identity.rb"), "class Identity; def self.id = 42; end\nDefault = Identity\n")
      provider = Mayu::Build::Configuration.new(root:).development_provider
      environment = Mayu::Environment.new(config(root), module_provider: provider, metrics: Object.new)
      yield environment, root, provider
    end
  end

  def config(root)
    server =
      Mayu::Configuration::ServerConfig.new(
        listen: "http://localhost:3000",
        hmr?: false,
        render_exceptions?: false,
        self_signed_cert?: false,
        h2c?: false,
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
