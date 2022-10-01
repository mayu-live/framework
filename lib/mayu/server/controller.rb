# typed: strict
# frozen_string_literal: true

require_relative "server"
require_relative "prometheus_server"

module Mayu
  module Server
    class Controller < Async::Container::Controller
      extend T::Sig

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
        @debug_trap = T.let(Async::IO::Trap.new(:USR1), Async::IO::Trap)
        @endpoint = endpoint
        @bound_endpoint = T.let(nil, T.nilable(Async::IO::SharedEndpoint))
      end

      sig { returns(Async::Container::Generic) }
      def create_container
        Async::Container::Hybrid.new
      end

      sig { void }
      def start
        @bound_endpoint =
          Async { Async::IO::SharedEndpoint.bound(@endpoint) }.wait

        Console.logger.info(self) { "Starting server on #{@endpoint.to_url}" }

        @debug_trap.ignore!
        super
      end

      sig { params(args: T.untyped).void }
      def stop(*args)
        Console.logger.warn("Stop", args)
        @bound_endpoint&.close
        @debug_trap.default!
        super
      end

      sig do
        params(container: Async::Container::Generic).returns(
          Async::Container::Generic
        )
      end
      def setup(container)
        if @config.metrics.enabled
          Console.logger.info(self, "Setting up metrics")

          container.async do
            Metrics.setup_prometheus_data_store(@config)
            PrometheusServer.start(@config)
          end
        end

        container.run(
          name: self.class.name,
          restart: true,
          count: @config.server.count,
          threads: @config.server.threads,
          forks: @config.server.forks
        ) do |instance|
          Async do |task|
            Metrics.setup_prometheus_data_store(@config)

            task.async do
              if @debug_trap.install!
                Console
                  .logger
                  .info(instance) do
                    "- Per-process status: kill -USR1 #{Process.pid}"
                  end
              end

              @debug_trap.trap do
                Console
                  .logger
                  .info(self) { |buffer| task.reactor.print_hierarchy(buffer) }
              end
            end

            endpoint = @bound_endpoint or raise "@bound_endpoint is not set"

            run_server(endpoint:)

            instance.ready!
            task.children.each(&:wait)

            Console.logger.warn("Ending server")
          end
        end
      end

      sig { params(endpoint: Async::IO::SharedEndpoint).void }
      def run_server(endpoint:)
        environment = Mayu::Environment.new(@config)
        server = Server.new(environment)

        start_hot_swap(environment, server) if @config.server.hot_swap

        Async::HTTP::Server
          .for(
            endpoint,
            protocol: Async::HTTP::Protocol::HTTP2,
            scheme: @config.server.scheme
          ) { |request| Protocol::HTTP::Response[*server.call(request)] }
          .run
      end

      sig { params(environment: Environment, server: Server).void }
      def start_hot_swap(environment, server)
        if @config.server.count > 1
          # It probably works, but it will be inefficient and pointless.
          Console.logger.error(
            self,
            "Can't start hot swap with more than 1 server."
          )
          return
        end

        if @config.use_bundle
          Console.logger.error(
            self,
            "Disabling hot swap because bundle is used"
          )
          return
        end

        require_relative "../resources/hot_swap"

        Console.logger.info("Starting hot swap")

        Resources::HotSwap.start(environment.resources) do
          Console.logger.info(
            self,
            Colors.rainbow("Detected code changes, rerendering.")
          )
          server.rerender
        end
      end
    end
  end
end
