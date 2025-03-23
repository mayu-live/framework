# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "async/barrier"
require "async/queue"
require "async/variable"
require "async/http/endpoint"
require "async/http/protocol/response"
require "async/http/server"

require_relative "server/app"
require_relative "metrics/server"

module Mayu
  class Server
    def initialize(environment)
      @uri = URI.parse(environment.config.server.listen)
      @app = App.new(environment)

      ssl_context =
        if environment.config.server.self_signed_cert?
          self_signed_cert_ssl_context(@uri.hostname)
        else
          nil
        end

      endpoint = Async::HTTP::Endpoint.new(@uri, ssl_context:)

      @server =
        Async::HTTP::Server.new(
          @app,
          endpoint,
          scheme: @uri.scheme,
          protocol: Async::HTTP::Protocol::HTTP2
        )

      @metrics_server =
        Metrics::Server.new(
          registry: Prometheus::Client.registry,
          listen: environment.config.metrics.listen
        ) if environment.config.metrics.enabled?
    end

    def run(task: Async::Task.current)
      task.async do
        interrupt = trap(:INT)

        puts "\e[33mStarting server on \e[94m#{@uri}\e[0m"

        @server.run
        @metrics_server&.run

        Console.logger.info(self, "Application started")

        interrupt.wait

        Console.logger.info("Got interrupt, stopping app")

        begin
          @app.stop
        ensure
          task.stop
        end
      rescue Errno::EADDRINUSE => e
        puts format("\e[3;31m %s \e[0m", e.message)
        exit 1
      ensure
        Console.logger.info(self, "Stopped server")
      end
    end

    private

    def self_signed_cert_ssl_context(hostname)
      require "localhost"

      authority = Localhost::Authority.fetch(hostname)

      ssl_context = authority.server_context

      ssl_context.alpn_select_cb = ->(protocols) do
        protocols.include?("h2") ? "h2" : nil
      end

      ssl_context.alpn_protocols = ["h2"]
      ssl_context.session_id_context = "mayu"

      ssl_context
    end

    def trap(signal)
      variable = Async::Variable.new

      previous =
        Signal.trap(signal) do
          Signal.trap(signal, previous)
        ensure
          variable.resolve(signal)
        end

      variable
    end
  end
end
