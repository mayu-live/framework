# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "async/io/trap"
require "async/barrier"
require "async/queue"
require "async/http/endpoint"
require "async/http/protocol/response"
require "async/http/server"

require_relative "server/app"

module Mayu
  class Server
    def initialize(config)
      @uri = URI.parse(config.server.listen)
      @app = App.new(config)

      endpoint = Async::HTTP::Endpoint.new(@uri)

      if config.server.self_signed_cert?
        endpoint = apply_local_certificate(endpoint)
      end

      @server =
        Async::HTTP::Server.new(
          @app,
          endpoint,
          scheme: @uri.scheme,
          protocol: Async::HTTP::Protocol::HTTP2
        )
    end

    def run(task: Async::Task.current)
      interrupt = Async::IO::Trap.new(:INT)

      task.async do
        interrupt.install!
        puts "\e[3m Starting server on #{@uri} \e[0m"

        barrier = Async::Barrier.new

        listeners = @server.run

        interrupt.wait
        Console.logger.info("Got interrupt")

        @app.stop
        interrupt.default!

        task.stop
      rescue Errno::EADDRINUSE => e
        puts format("\e[3;31m %s \e[0m", e.message)
        exit 1
      ensure
        Console.logger.info("Stopped server")
      end
    end

    private

    def apply_local_certificate(endpoint)
      require "localhost"
      require "async/io/ssl_endpoint"

      authority = Localhost::Authority.fetch(endpoint.hostname)

      context = authority.server_context
      context.alpn_select_cb = ->(protocols) do
        protocols.include?("h2") ? "h2" : nil
      end

      context.alpn_protocols = ["h2"]
      context.session_id_context = "mayu"

      Async::IO::SSLEndpoint.new(endpoint, ssl_context: context)
    end
  end
end
