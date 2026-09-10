# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "async/signals"
require "async/container"
require "async/container/controller"
require "async/container/forked"
require_relative "worker"

require_relative "app"
require_relative "../metrics"
require_relative "../environment"
require_relative "../warning_filter"

module Mayu
  class Server
    class Controller < Async::Container::Controller
      def initialize(
        config:,
        mayu_env:,
        endpoint:,
        bundle_filename: nil,
        **options
      )
        super(**options)
        @config = config
        @mayu_env = mayu_env
        @endpoint = endpoint
        @bundle_filename = bundle_filename
        @bound_endpoint = nil
        @graceful_stop = @config.server.shutdown_timeout_seconds + Worker::CLEANUP_TIMEOUT_SECONDS
      end

      def create_container
        Async::Container::Forked.new
      end

      def start
        return if @container
        @bound_endpoint = Sync { @endpoint.bound }
        # Publish the container before startup so a first interrupt can drain
        # children which have already started, even if others are not ready.
        @container = create_container
        setup(@container)
        @container.wait_until_ready
        raise Async::Container::SetupError, @container if @container.failed?
        @notify&.ready!(size: @container.size)
      end

      def run
        with_signal_handlers do
          start
          while @container&.running?
            begin
              @container.wait
            rescue Async::Container::Restart
              restart
            end
          end
        rescue Interrupt
          Console.logger.info(self, "Graceful shutdown requested", pid: Process.pid)
          stop
        ensure
          stop(false)
        end
      end

      def stop(graceful = @graceful_stop)
        @bound_endpoint&.close
        super
      rescue Interrupt
        # Group#stop also kills its remaining children when interrupted. Keep
        # the controller reference until they have all been reaped.
        Console.logger.warn(self, "Second interrupt: forcing shutdown", pid: Process.pid)
        super(false)
      end

      def setup(container)
        collector_endpoint = nil

        if @config.metrics.enabled?
          collector_endpoint = Metrics.collector_endpoint(@config.root)
          setup_metrics_server(container, collector_endpoint)
        end

        container.run(
          name: self.class.name,
          count: worker_count,
          restart: true
        ) { |instance| setup_worker(instance, collector_endpoint:) }
      end

      private

      def with_signal_handlers
        interrupts = 0
        handlers = Async::Signals::Handlers.new
        [:INT, :TERM].each do |name|
          handlers.trap(name) do |signal, context|
            interrupts += 1
            context.raise(Interrupt) if interrupts <= 2
          end
        end
        handlers.trap(:HUP) do |signal, context|
          context.raise(Async::Container::Restart) if interrupts.zero?
        end
        Thread.handle_interrupt(SignalException => :never) do
          Async::Signals.install(handlers) { yield }
        end
      end

      def setup_metrics_server(container, collector_endpoint)
        Metrics.start_collect_and_export(
          container,
          collector_endpoint:,
          listen: @config.metrics.listen,
          shutdown_timeout: @config.server.shutdown_timeout_seconds,
          inherited_endpoint: @bound_endpoint
        ) { |registry| Metrics::AppMetrics.setup(registry) }
      end

      def setup_worker(instance, collector_endpoint:)
        Worker.new(
          config: @config,
          endpoint: @endpoint,
          bound_endpoint: @bound_endpoint,
          collector_endpoint:
        ) { |metrics| load_environment(metrics:) }.run(instance)
      end

      def load_environment(metrics:)
        case @mayu_env
        in :development
          Environment.with_config(@config, metrics:)
        in :production
          bundle_filename = @bundle_filename || raise("Missing bundle filename")
          Environment.load_klenod_with_config(
            @config,
            bundle_filename,
            metrics:
          )
        end
      end

      def worker_count
        return 1 if @mayu_env == :development

        Async::Container.processor_count
      end
    end
  end
end
