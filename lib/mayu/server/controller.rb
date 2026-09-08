# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "async/container"
require "async/container/controller"
require "async/container/forked"
require "async/http/server"

require_relative "app"
require_relative "../metrics"
require_relative "../environment"
require_relative "../silence_io_buffer_warning"

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
        @graceful_stop = 10
      end

      def create_container
        Async::Container::Forked.new
      end

      def start
        @bound_endpoint = Sync { @endpoint.bound }
        super
      end

      def stop(graceful = @graceful_stop)
        super
      ensure
        @bound_endpoint&.close
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

      def setup_metrics_server(container, collector_endpoint)
        Metrics.start_collect_and_export(
          container,
          collector_endpoint:,
          listen: @config.metrics.listen
        ) { |registry| Metrics::AppMetrics.setup(registry) }
      end

      def setup_worker(instance, collector_endpoint:)
        Async do |task|
          reporter = nil
          metrics = nil
          environment = nil
          asset_task = nil
          watcher_task = nil

          if collector_endpoint
            reporter =
              Metrics::Reporter.run(collector_endpoint, task:) do |registry|
                Metrics::AppMetrics.setup(registry)
              end

            metrics = reporter.metrics
          end

          environment = load_environment(metrics:)

          if @mayu_env == :development
            watcher_task =
              (environment.start_watcher if environment.config.server.hmr?)
          end

          environment.use do
            app = nil
            server_task = nil

            begin
              app = App.new(environment)

              server =
                Async::HTTP::Server.for(
                  @bound_endpoint,
                  protocol: @endpoint.protocol,
                  scheme: @endpoint.scheme
                ) { |request| app.call(request) }

              server_task = server.run
              instance.ready!

              task.wait_all
            ensure
              reporter&.stop
              app&.stop
              server_task&.stop
            end
          end
          # rescue Interrupt
          #   Console.logger.info(self, "Got interrupt")
        ensure
          watcher_task&.stop
          asset_task&.stop
          reporter&.stop
        end
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

        [
          1,
          ENV.fetch("WEB_CONCURRENCY") { Async::Container.processor_count }.to_i
        ].max
      end
    end
  end
end
