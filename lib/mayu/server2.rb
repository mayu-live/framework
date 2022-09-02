# typed: strict

require "bundler/setup"
require "sorbet-runtime"
require "async"
require "async/container"
require "async/http/server"
require "async/http/endpoint"
require "async/io/host_endpoint"
require "async/io/shared_endpoint"
require "async/io/ssl_endpoint"
require "localhost"

module Mayu
  module Server2
    module SessionAPI
      extend T::Sig

      #sig {params(request: Async::HTTP::Request, session_id: String, args: T::Array[String]).void}
      def self.handle(request, session_id, args)
        case [request.method, args]
        in ["GET", ["events"]]
          body = Async::HTTP::Body::Writable.new
          Protocol::HTTP::Response[
            200,
            { "content-type" => "text/event-stream; charset=utf-8" },
            body
          ]
        in ["callback", "ping"]
          Protocol::HTTP::Response[
            200,
            { "content-type" => "text/plain; charset=utf-8" },
            ["pong"]
          ]
        in ["callback", callback_id]
        end
      end
    end

    extend T::Sig

    sig do
      params(host: String, port: Integer, count: Integer).returns(
        Async::Container::Forked
      )
    end
    def self.start_dev(host: "localhost", port: 7811, count: 1)
      uri = URI.for("https", nil, host, port, nil, "/", nil, nil, nil).normalize

      ssl_context = dev_ssl_context(host)
      server_endpoint =
        Async::HTTP::Endpoint.new(uri, ssl_context:, reuse_port: true)
      bound_endpoint =
        Async { Async::IO::SharedEndpoint.bound(server_endpoint) }.wait

      Console.logger.info(self) { "Starting server on https://#{host}:#{port}" }

      start_container(endpoint: bound_endpoint, count:)
    end

    sig { params(host: String).returns(OpenSSL::SSL::SSLContext) }
    def self.dev_ssl_context(host)
      authority = Localhost::Authority.fetch(host)

      authority.server_context.tap do |context|
        context.alpn_select_cb =
          lambda { |protocols| protocols.include?("h2") ? "h2" : nil }

        context.alpn_protocols = ["h2"]
        context.session_id_context = "mayu"
      end
    end

    sig do
      params(endpoint: Async::IO::Endpoint, count: Integer).returns(
        Async::Container::Forked
      )
    end
    def self.start_container(endpoint:, count:)
      Console.logger.info(self, "Starting container...")

      Async::Container::Forked
        .new
        .run(count:, restart: true) do |instance|
          Console.logger.info(self, "Child process started.")

          Async do |task|
            server = setup_server(endpoint:)
            server.run
            instance.ready!
            task.children.each(&:wait)
          end
        ensure
          Console.logger.info(self, "Child processes exiting:", $!)
        end
    end

    sig { params(endpoint: Async::IO::Endpoint).returns(Async::HTTP::Server) }
    def self.setup_server(endpoint:)
      Async::HTTP::Server.for(
        endpoint,
        protocol: Async::HTTP::Protocol::HTTP2,
        scheme: "https"
      ) do |request|
        case [request.method, request.path.delete_prefix("/").split("/")]
        in [String, ["__mayu", "session", String => session_id, *args]]
          SessionAPI.handle(request, session_id, args)
        in ["GET", []]
          Protocol::HTTP::Response[
            200,
            { "content-type" => "text/plain" },
            ["Hello World"]
          ]
        end
      end
    end
  end
end

Mayu::Server2.start_dev(port: 1234, count: 2).wait
