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
        with_environment do |environment|
          Async do |task|
            app = App.new(environment)
            server_task = nil

            if @mayu_env == :development &&
                 environment.config.server.generate_assets?
              environment.modules.generate_assets(
                environment.assets_dir,
                concurrency: 1,
                forever: true
              )
            end

            server =
              Async::HTTP::Server.for(
                @bound_endpoint,
                protocol: @endpoint.protocol,
                scheme: @endpoint.scheme
              ) { |request| app.call(request) }

            server_task = server.run

            instance.ready!

            task.children.each(&:wait)
          ensure
            app&.stop
            server_task&.stop
          end
        end
      end

      def with_environment
        case @mayu_env
        in :development
          Environment.with_config(@config) { |environment| yield environment }
        in :production
          bundle_filename = @bundle_filename || raise("Missing bundle filename")
          bundle = File.read(bundle_filename, encoding: "binary")

          Environment.load_with_config(@config, bundle) do |environment|
            yield environment
          end
        end
      end

      def worker_count
        return 1 if @mayu_env == :development

        ENV
          .fetch("WEB_CONCURRENCY") { Async::Container.processor_count }
          .to_i
          .yield_self { _1 > 0 ? _1 : 1 }
      end
    end
  end
end
