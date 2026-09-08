#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

require_relative "environment"

class Mayu::EnvironmentTest < Minitest::Test
  def test_load_klenod_with_config_uses_runtime_provider_without_legacy_state
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "entry.rb"), "VALUE = 42\n")

      bundle_path = File.join(root, "app.mayu-bundle")
      Mayu::Klenod::Configuration.new(root:, entrypoints: ["entry"]).build(
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

  def test_development_environment_uses_klenod_without_legacy_state
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "root.haml"), "%slot\n")

      environment =
        Mayu::Environment.with_config(config(root), metrics: Object.new)

      assert_instance_of(
        Mayu::Klenod::DevelopmentProvider,
        environment.module_provider
      )
    end
  end

  def test_klenod_update_subscriptions_receive_each_central_update_once
    environment =
      Mayu::Environment.new(
        config(Dir.mktmpdir("mayu-klenod")),
        module_provider: Object.new,
        metrics: Object.new
      )
    updates = []
    subscription =
      environment.subscribe_klenod_updates { |update| updates << update }

    environment.send(:publish_klenod_update, :updated)
    environment.unsubscribe_klenod_updates(subscription)
    environment.send(:publish_klenod_update, :ignored)

    assert_equal([:updated], updates)
  end

  def test_klenod_update_subscriptions_fan_out_once_to_each_subscriber
    environment =
      Mayu::Environment.new(
        config(Dir.mktmpdir("mayu-klenod")),
        module_provider: Object.new,
        metrics: Object.new
      )
    first = []
    second = []
    environment.subscribe_klenod_updates { |update| first << update }
    environment.subscribe_klenod_updates { |update| second << update }

    environment.send(:publish_klenod_update, :updated)

    assert_equal([:updated], first)
    assert_equal([:updated], second)
  end

  def test_klenod_watcher_applies_an_update_once_and_publishes_it
    Dir.mktmpdir("mayu-klenod") do |root|
      app_dir = File.join(root, "app")
      FileUtils.mkdir_p(app_dir)
      root_path = File.join(app_dir, "root.haml")
      css_path = File.join(app_dir, "root.css")
      File.write(root_path, "%p Before\n")

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      environment =
        Mayu::Environment.new(
          config(root),
          module_provider: provider,
          metrics: Object.new
        )
      updates = Async::Queue.new
      environment.subscribe_klenod_updates { |update| updates.enqueue(update) }

      Async do
        watcher_task = environment.start_watcher
        File.write(css_path, "p { color: red; }\n")
        result = provider.context.invalidate_paths([css_path])
        provider.context.emit_update(
          ::Klenod::Build::UpdateEvent.new([css_path], [], 1, result)
        )

        update = updates.dequeue(timeout: 2)

        assert(update.success?)
        assert_equal([css_path], update.event.changed_paths)
        assert_equal(
          ["app:/root.haml"],
          update.event.result.reloaded_module_ids.map(&:to_s)
        )
        assert(update.asset_files_changed?)
        assert(File.file?(update.written_asset_paths.first))
      ensure
        watcher_task&.stop
      end.wait
    end
  end

  def test_klenod_watcher_recovers_after_a_failed_update
    Dir.mktmpdir("mayu-klenod") do |root|
      app_dir = File.join(root, "app")
      FileUtils.mkdir_p(app_dir)
      root_path = File.join(app_dir, "root.haml")
      File.write(root_path, "%p Before\n")

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      environment =
        Mayu::Environment.new(
          config(root),
          module_provider: provider,
          metrics: Object.new
        )
      updates = Async::Queue.new
      environment.subscribe_klenod_updates { |update| updates.enqueue(update) }

      Async do
        watcher_task = environment.start_watcher

        File.write(root_path, "= @columns.map do |column| }\n  %p= column\n")
        publish_update(provider, root_path, graph_version: 1)
        failed = updates.dequeue(timeout: 2)

        refute(failed.success?)
        assert_equal([], failed.written_asset_paths)

        File.write(root_path, "%p After\n")
        publish_update(provider, root_path, graph_version: 2)
        recovered = updates.dequeue(timeout: 2)

        assert(recovered.success?)
        assert_includes(
          provider.context.entry("root.haml").record.transformed_source,
          "After"
        )
      ensure
        watcher_task&.stop
      end.wait
    end
  end

  def test_klenod_watcher_removes_deleted_assets
    Dir.mktmpdir("mayu-klenod") do |root|
      app_dir = File.join(root, "app")
      FileUtils.mkdir_p(app_dir)
      root_path = File.join(app_dir, "root.haml")
      css_path = File.join(app_dir, "root.css")
      File.write(root_path, "%slot\n")
      File.write(css_path, "p { color: red; }\n")

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      environment =
        Mayu::Environment.new(
          config(root),
          module_provider: provider,
          metrics: Object.new
        )
      updates = Async::Queue.new
      environment.subscribe_klenod_updates { |update| updates.enqueue(update) }

      Async do
        watcher_task = environment.start_watcher

        File.delete(css_path)
        result =
          provider.context.invalidate_paths([], removed_paths: [css_path])
        provider.context.emit_update(
          ::Klenod::Build::UpdateEvent.new([], [css_path], 1, result)
        )

        update = updates.dequeue(timeout: 2)

        assert(update.success?)
        assert_equal([css_path], update.event.removed_paths)
        assert(update.asset_files_changed?)
        assert(update.removed_asset_paths.any?)
      ensure
        watcher_task&.stop
      end.wait
    end
  end

  def test_klenod_watcher_updates_added_and_removed_routes
    Dir.mktmpdir("mayu-klenod") do |root|
      app_dir = File.join(root, "app")
      pages_dir = File.join(app_dir, "pages")
      route_dir = File.join(pages_dir, "about")
      route_path = File.join(route_dir, "+page.haml")
      FileUtils.mkdir_p(pages_dir)
      File.write(File.join(app_dir, "root.haml"), "%slot\n")
      File.write(File.join(pages_dir, "+page.haml"), "%p Home\n")

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      environment =
        Mayu::Environment.new(
          config(root),
          module_provider: provider,
          metrics: Object.new
        )
      router = Mayu::Klenod::Router.new(provider)
      assert_nil(router.resolve("/about"))

      updates = Async::Queue.new
      environment.subscribe_klenod_updates { |update| updates.enqueue(update) }

      Async do
        watcher_task = environment.start_watcher

        FileUtils.mkdir_p(route_dir)
        File.write(route_path, "%p About\n")
        publish_update(provider, route_path, graph_version: 1)
        added = updates.dequeue(timeout: 2)

        assert(added.success?)
        assert_equal(200, router.resolve("/about").status)

        File.delete(route_path)
        result =
          provider.context.invalidate_paths([], removed_paths: [route_path])
        provider.context.emit_update(
          ::Klenod::Build::UpdateEvent.new([], [route_path], 2, result)
        )
        removed = updates.dequeue(timeout: 2)

        assert(removed.success?)
        assert_nil(router.resolve("/about"))
      ensure
        watcher_task&.stop
      end.wait
    end
  end

  private

  def publish_update(provider, path, graph_version:)
    result = provider.context.invalidate_paths([path])
    provider.context.emit_update(
      ::Klenod::Build::UpdateEvent.new([path], [], graph_version, result)
    )
  end

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
