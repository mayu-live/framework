# frozen_string_literal: true

require "async"
require "async/promise"
require_relative "shutdown_signal"
require_relative "http_server"
require_relative "app"

module Mayu
  class Server
    class Worker
      CLEANUP_TIMEOUT_SECONDS = 5

      def initialize(config:, endpoint:, bound_endpoint:, collector_endpoint: nil, &load_environment)
        @config = config
        @endpoint = endpoint
        @bound_endpoint = bound_endpoint
        @collector_endpoint = collector_endpoint
        @load_environment = load_environment
      end

      def run(instance)
        ShutdownSignal.open do |signal|
          Async do |task|
            if @collector_endpoint
              @reporter = Metrics::Reporter.run(@collector_endpoint, task:) do |registry|
                Metrics::AppMetrics.setup(registry)
              end
            end

            environment = @load_environment.call(@reporter&.metrics)
            @app = App.new(environment)
            @watcher = environment.start_watcher if environment.config.server.hmr?
            @server = HTTPServer.new(
              @app,
              @bound_endpoint,
              protocol: @endpoint.protocol,
              scheme: @endpoint.scheme
            )

            unless signal.requested?
              finished = Async::Promise.new
              listener = @server.run
              task.async do
                listener.wait_all
                finished.reject(RuntimeError.new("HTTP listener stopped unexpectedly")) unless finished.resolved?
              rescue => error
                finished.reject(error) unless finished.resolved?
              end
              task.async do
                signal.wait
                finished.resolve(true) unless finished.resolved?
              end
              instance.ready!
              finished.wait
            end

            drain(task)
          ensure
            cleanup(task)
          end.wait
        end
      end

      private

      def drain(task)
        Console.logger.info(self, "Draining worker", pid: Process.pid)
        task.with_timeout(@config.server.shutdown_timeout_seconds) do
          @app.begin_shutdown
          @server.stop_accepting
          @watcher&.stop
          @app.stop
        end
        Console.logger.info(self, "Worker drained", pid: Process.pid)
      rescue Async::TimeoutError
        Console.logger.warn(self, "Worker drain deadline expired", pid: Process.pid, streams: @app.stream_count)
      end

      def cleanup(task)
        task.with_timeout(CLEANUP_TIMEOUT_SECONDS) do
          [-> { @app&.abort }, -> { @server&.stop }, -> { @watcher&.stop },
            -> { @reporter&.stop }, -> { @bound_endpoint.close }].each do |operation|
            operation.call
          rescue => error
            raise if error.is_a?(Async::TimeoutError)
            Console.logger.error(self, error)
          end
        end
      rescue Async::TimeoutError
        Console.logger.warn(self, "Worker cleanup deadline expired", pid: Process.pid)
      ensure
        task.children&.to_a&.each(&:stop)
      end
    end
  end
end
