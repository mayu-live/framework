# typed: strict
# frozen_string_literal: true

require "async/container/controller"
require "async/io/shared_endpoint"
require "async/io/trap"
require_relative "app"
require_relative "../metrics"
require_relative "../app_metrics"

module Mayu
  module Server
    class Controller < Async::Container::Controller
      extend T::Sig

      sig { returns(Async::Container::Generic) }
      def create_container
        Async::Container::Hybrid.new
      end

      sig do
        params(
          config: Configuration,
          endpoint: Async::HTTP::Endpoint,
          options: T.untyped
        ).void
      end
      def initialize(config:, endpoint:, **options)
        super(**options)
        @config = config
        @endpoint = endpoint
        @interrupt_trap = T.let(Async::IO::Trap.new(:INT), Async::IO::Trap)
        @bound_endpoint = T.let(nil, T.nilable(Async::IO::SharedEndpoint))
      end

      sig { void }
      def start
        Console.logger.info(self, "Binding to #{@endpoint.url}")

        @bound_endpoint =
          Async { Async::IO::SharedEndpoint.bound(@endpoint) }.wait

        super
      end

      sig { params(timeout: T::Boolean).void }
      def stop(timeout = true)
        super(timeout && 5)
      end

      sig { params(container: Async::Container::Generic).void }
      def setup(container)
        collector_endpoint = Async::IO::Endpoint.unix("metrics.ipc")
        exporter_endpoint = Async::HTTP::Endpoint.parse("http://[::]:9092")

        Metrics.start_collect_and_export(
          container,
          collector_endpoint:,
          exporter_endpoint:
        ) { |registry| AppMetrics.setup(registry, instance_id: "Collector") }

        # TODO: We're waiting for the collector to start.
        # Better make start_collect_and_export block until started.
        sleep 0.2

        container.run(
          name: "mayu-live server",
          count: @config.server.count,
          threads: @config.server.threads,
          forks: @config.server.forks
        ) do |instance, asd|
          Async do |task|
            interrupt = Async::Notification.new

            metrics =
              Metrics::Reporter.run(collector_endpoint) do |registry|
                AppMetrics.setup(registry)
              end

            task.async do
              @interrupt_trap.install!

              @interrupt_trap.trap { interrupt.signal }
            end

            environment = Environment.new(@config, metrics)
            app = App.new(environment:)

            server =
              Async::HTTP::Server.new(
                app,
                @bound_endpoint,
                protocol: Async::HTTP::Protocol::HTTP2,
                scheme: @endpoint.scheme
              )

            start_hot_swap(environment, app) if @config.server.hot_swap

            if @config.server.generate_assets
              environment.resources.run_asset_generator(
                environment.path(:assets),
                concurrency: 4
              )
            end

            server_task = server.run

            task.async do
              loop do
                sleep 1
                app.clear_expired_sessions!
              end
            end

            instance.ready!

            interrupt.wait
            app.stop
            raise Interrupt
          end
        rescue => e
          Console.logger.error(self, e)
        end
      end

      sig { params(environment: Environment, app: App, task: Async::Task).void }
      def start_hot_swap(environment, app, task: Async::Task.current)
        task.async do
          if environment.config.use_bundle
            Console.logger.error(
              self,
              "Disabling hot swap because bundle is used"
            )
            return
          end

          require_relative "../resources/hot_swap"

          Resources::HotSwap.start(environment.resources) do
            Console.logger.info(
              self,
              Colors.rainbow("Detected code changes, rerendering.")
            )

            app.rerender
          end
        end
      end
    end
  end
end
