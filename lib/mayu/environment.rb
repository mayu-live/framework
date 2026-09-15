# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "encrypted_marshal"
require_relative "configuration"
require_relative "component"
require_relative "metrics"
require_relative "utils"
require_relative "klenod"

module Mayu
  class Environment
    attr_reader :config
    attr_reader :app_dir
    attr_reader :client_path
    attr_reader :runtime_js_path
    attr_reader :init_js_body
    attr_reader :module_provider
    attr_reader :marshaller
    attr_reader :metrics

    def self.client_runtime_entries_path
      File.join(__dir__, "client", "dist", "entries.json")
    end

    def self.ensure_client_runtime!
      return if File.file?(client_runtime_entries_path)

      raise "Mayu browser runtime is missing at #{client_runtime_entries_path}. Run `npm run build` before starting the server."
    end

    def self.with(mayu_env)
      Configuration.with(mayu_env) do |config|
        with_config(config).use { |environment| yield environment }
      end
    end

    def self.with_config(config, metrics: nil)
      new(config, metrics:)
    end

    def initialize(config, module_provider: nil, metrics: nil)
      @config = config
      @app_dir = File.join(config.root, Klenod::SOURCE_DIR)
      @client_path = File.join(__dir__, "client", "dist")

      @runtime_js_path = load_runtime_js_path
      @init_js_body = <<~JS.freeze
        import init from #{JSON.generate(@runtime_js_path)};
        const sessionId = new URL(import.meta.url).hash.slice(1);
        init(sessionId);
      JS

      @metrics =
        metrics || Metrics::AppMetrics.setup(Prometheus::Client.registry)

      @marshaller =
        EncryptedMarshal.new(
          config.secret_key,
          ttl: config.server.transfer_timeout_seconds
        )

      @module_provider =
        module_provider ||
        Klenod::Configuration.new(root: config.root).development_provider
      @klenod_update_subscribers = {}
      @klenod_update_subscribers_mutex = Mutex.new
      @start_hooks = []
      @started = []
    end

    # Loads a prebuilt bundle. Nothing on this path may need klenod-build.
    def self.load_klenod_with_config(
      config,
      bundle_path,
      metrics: nil,
      source_root: nil,
      assets_dir: nil
    )
      module_provider =
        Klenod::RuntimeProvider.load(
          bundle_path,
          source_root: source_root || File.join(config.root, Klenod::SOURCE_DIR),
          assets_dir: assets_dir || File.join(config.root, Klenod::ASSETS_DIR)
        )

      new(config, module_provider:, metrics:)
    end

    def use(&)
      yield self
    end

    # Registers work to run in the worker once its App exists. A hook may
    # return something responding to `stop`, which `stop` then calls when the
    # worker drains.
    def on_start(&block)
      @start_hooks << block
    end

    def start(app)
      @started = @start_hooks.filter_map { it.call(app) }
    end

    def stop
      started = @started
      @started = []
      started.each { it.stop if it.respond_to?(:stop) }
    end

    def start_watcher
      return unless @module_provider.is_a?(Klenod::DevelopmentProvider)

      start_klenod_watcher
    end

    def subscribe_klenod_updates(&block)
      token = Object.new
      @klenod_update_subscribers_mutex.synchronize do
        @klenod_update_subscribers[token] = block
      end
      token
    end

    def unsubscribe_klenod_updates(token)
      @klenod_update_subscribers_mutex.synchronize do
        @klenod_update_subscribers.delete(token)
      end
    end

    private

    def start_klenod_watcher
      provider = @module_provider
      context = provider.context
      root_entry = provider.entry("root.haml")
      updates = Async::Queue.new
      context.on_update { |event| updates.enqueue(event) }

      watcher =
        ::Klenod::Build::Watcher.new(
          source_dir: @app_dir,
          context:
        )

      Async do
        watcher.start

        loop do
          event = updates.dequeue
          publish_klenod_update(apply_klenod_update(provider, event, root_entry))
        end
      ensure
        updates.close
        watcher.stop
      end
    end

    # Anything escaping here would break out of the watcher loop and stop hot
    # reloading for the rest of the process, so report the failure as an update
    # instead and let sessions render it.
    def apply_klenod_update(provider, event, root_entry)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      update = provider.apply_update(event, entry: root_entry)
      update_logger.log(update:, duration: format_duration(start_time))
      update
    rescue StandardError, ScriptError => e
      Console.logger.error(self, e)
      ::Klenod::Build::AppliedUpdate.new(event, nil, nil, nil, [[nil, e]].freeze)
    end

    def publish_klenod_update(update)
      subscribers =
        @klenod_update_subscribers_mutex.synchronize do
          @klenod_update_subscribers.values
        end
      subscribers.each { |subscriber| subscriber.call(update) }
    end

    def update_logger
      @update_logger ||=
        Klenod::UpdateLogger.new(
          source_dir: @app_dir,
          provider: @module_provider
        )
    end

    def format_duration(start_time)
      "%.4fms" % ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1_000)
    end

    def load_runtime_js_path
      self.class.ensure_client_runtime!
      File
        .read(self.class.client_runtime_entries_path)
        .then { JSON.parse(it) }
        .fetch("main")
        .then { File.join("/.mayu/runtime", it) }
    end
  end
end
