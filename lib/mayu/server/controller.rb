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
        # setup_metrics_server(container) if @config.metrics.enabled?

        container.run(
          name: self.class.name,
          count: worker_count,
          restart: true
        ) { |instance| setup_worker(instance) }
      end

      private

      def setup_metrics_server(container)
        container.run(
          name: "Mayu metrics",
          count: 1,
          restart: true
        ) do |instance|
          Async do |task|
            Metrics::AppMetrics.setup(Prometheus::Client.registry)

            metrics_server =
              Metrics::Server.new(
                registry: Prometheus::Client.registry,
                listen: @config.metrics.listen
              )

            instance.ready!
            metrics_server.run

            task.children.each(&:wait)
          end
        end
      end

      def setup_worker(instance)
        environment =
          case @mayu_env
          in :development
            Environment.with_config(@config)
          in :production
            bundle_filename =
              @bundle_filename || raise("Missing bundle filename")
            bundle = File.read(bundle_filename, encoding: "binary")
            Environment.load_with_config(@config, bundle)
          end

        Async do |task|
          asset_task = nil

          if @mayu_env == :development
            if environment.config.server.generate_assets?
              asset_task =
                environment.modules.generate_assets(
                  environment.assets_dir,
                  concurrency: 1,
                  forever: true
                )
            end

            environment.start_watcher if environment.config.server.hmr?
          end

          environment.use do
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
            app&.stop
            server_task&.stop
          end
        ensure
          asset_task&.stop
        end

        puts "Started task"
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
