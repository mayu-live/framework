# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
        endpoint:,
        load_environment:,
        worker_count: nil,
        before_fork: nil,
        **options
      )
        super(**options)
        @config = config
        @endpoint = endpoint
        @load_environment = load_environment
        @before_fork = before_fork
        @worker_count = worker_count || Async::Container.processor_count
        @bound_endpoint = nil
        @graceful_stop = @config.server.shutdown_timeout_seconds + Worker::CLEANUP_TIMEOUT_SECONDS
      end

      def create_container
        Async::Container::Forked.new
      end

      def start
        return if @container
        Environment.ensure_client_runtime!
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
        # Runs in the controller while no child exists yet, on start and on
        # every restart. What it loads is shared with the workers copy-on-
        # write, and a SIGHUP still picks up a new bundle from disk.
        @before_fork&.call

        collector_endpoint = nil

        if @config.metrics.enabled?
          collector_endpoint = Metrics.collector_endpoint(@config.root)
          setup_metrics_server(container, collector_endpoint)
          # The collector reports ready once its socket accepts connections.
          # Starting the workers only then spares every reporter a failed
          # first connection and the warning that goes with it.
          container.wait_until_ready
        end

        container.run(
          name: self.class.name,
          count: @worker_count,
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
        @load_environment.call(metrics:)
      end
    end
  end
end
