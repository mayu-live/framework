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
    attr_reader :klenod_configuration
    attr_reader :marshaller
    attr_reader :metrics

    def self.with(mayu_env)
      Configuration.with(mayu_env) do |config|
        with_config(config).use { |environment| yield environment }
      end
    end

    def self.with_config(config, metrics: nil)
      new(config, metrics:)
    end

    def initialize(
      config,
      module_provider: nil,
      klenod_configuration: nil,
      metrics: nil
    )
      @config = config
      @app_dir = File.join(config.root, "app")
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

      @klenod_configuration =
        klenod_configuration || Klenod::Configuration.load(root: config.root)
      @module_provider =
        module_provider || @klenod_configuration.development_provider
      @klenod_update_subscribers = {}
      @klenod_update_subscribers_mutex = Mutex.new
    end

    def self.load_klenod_with_config(config, bundle_path, metrics: nil)
      klenod_configuration =
        Klenod::Configuration.load(root: config.root, mode: :production)

      new(
        config,
        module_provider: klenod_configuration.runtime_provider(bundle_path:),
        klenod_configuration:,
        metrics:
      )
    end

    def use(&)
      yield self
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
          source_dir: @klenod_configuration.source_path,
          context:
        )

      Async do
        watcher.start

        loop do
          event = updates.dequeue
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          update = provider.apply_update(event, entry: root_entry)
          update_logger.log(update:, duration: format_duration(start_time))
          publish_klenod_update(update)
        end
      ensure
        updates.close
        watcher.stop
      end
    end

    def publish_klenod_update(update)
      subscribers =
        @klenod_update_subscribers_mutex.synchronize do
          @klenod_update_subscribers.values
        end
      subscribers.each { |subscriber| subscriber.call(update) }
    end

    def update_logger
      @update_logger ||= Klenod::UpdateLogger.new(source_dir: @klenod_configuration.source_path)
    end

    def format_duration(start_time)
      "%.4fms" % ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1_000)
    end

    def load_runtime_js_path
      File
        .read(File.join(@client_path, "entries.json"))
        .then { JSON.parse(it) }
        .fetch("main")
        .then { File.join("/.mayu/runtime", it) }
    end
  end
end
