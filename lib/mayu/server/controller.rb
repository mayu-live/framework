# typed: strict
# frozen_string_literal: true

require_relative "server"

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
        container.run(
          name: self.class.name,
          restart: true,
          count: @config.num_processes
        ) do |instance|
          Async do |task|
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

        if @config.hot_swap
          Console.logger.info("Starting hot swap")

          environment.resources.start_hot_swap do
            Console.logger.info(
              self,
              Colors.rainbow("Detected code changes, rerendering.")
            )
            server.rerender
          end
        end

        Async::HTTP::Server
          .for(
            endpoint,
            protocol: Async::HTTP::Protocol::HTTP2,
            scheme: @config.scheme
          ) { |request| Protocol::HTTP::Response[*server.call(request)] }
          .run
      end
    end
  end
end
