# typed: strict

require "bundler/setup"
require "sorbet-runtime"
require "async"
require "async/container"
require "async/http/server"
require "async/io/host_endpoint"

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
    def self.start(host: "127.0.0.1", port: 7811, count: 1)
      endpoint = Async::IO::Endpoint.tcp(host, port)
      container = Async::Container.new

      Console.logger.info(self) { "Starting server..." }

      container
        .run(count:) do
          server =
            Async::HTTP::Server.for(
              endpoint,
              protocol: Async::HTTP::Protocol::HTTP11,
              scheme: "http"
            ) do |request|
              p request.headers
              p request.method
              p request.path

              p request

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

          Async { server.run }
        end
        .wait
    ensure
      container&.stop
    end

    def self.session_request(request, session_id, path)
    end
  end
end

Mayu::Server2.start
