# typed: strict

require "bundler/setup"
require "sorbet-runtime"
require "async"
require "async/container"
require "async/http/server"
require "async/http/endpoint"
require "protocol/http/body/file"
require "async/io/host_endpoint"
require "async/io/shared_endpoint"
require "async/io/ssl_endpoint"
require "localhost"
require "mime/types"
require_relative "environment"
require_relative "session"
require_relative "configuration"

module Mayu
  module Server2
    class Server
      extend T::Sig

      Status = T.type_alias { Integer }
      Headers = T.type_alias { T::Hash[String, String] }
      Body =
        T.type_alias do
          T.any(
            [String],
            Async::HTTP::Body::Writable,
            Protocol::HTTP::Body::File
          )
        end
      ResponseArray = T.type_alias { [Status, Headers, Body] }

      sig { returns(Environment) }
      attr_reader :environment

      sig { params(environment: Environment).void }
      def initialize(environment)
        @environment = environment
        @sessions = T.let({}, T::Hash[String, Session])
      end

      sig { params(request: Protocol::HTTP::Request).returns(ResponseArray) }
      def call(request)
        Console.logger.info(self) { "#{request.method} #{request.path}" }

        case [request.method, request.path.delete_prefix("/").split("/")]
        in ["POST", ["__mayu", "session", "resume", *_rest]]
          dumped = @environment.message_cipher.load(request.read)
          session = Session.restore(environment:, dumped:)

          @sessions[session_key(session.id, session.token)] = session

          headers = {
            "content-type" => "text/plain",
            "set-cookie" => session_token_cookie(session.id, session.token)
          }

          respond(headers:, body: [session.id])
        in ["POST", ["__mayu", "session", session_id, "ping"]]
          session = fetch_session(session_id, get_session_token_cookie(request))

          respond(
            headers: {
              "content-type" => "application/json"
            },
            body: [request.read]
          )
        in ["POST", ["__mayu", "session", session_id, "callback", callback_id]]
          session = fetch_session(session_id, get_session_token_cookie(request))
          payload = JSON.parse(request.read)
          session.handle_callback(callback_id, payload)
          [200, { "content-type" => "text/plain" }, ["ok"]]
        in ["GET", ["__mayu", "session", session_id, "events"]]
          session = fetch_session(session_id, get_session_token_cookie(request))

          body = Async::HTTP::Body::Writable.new

          body.write("retry: 1000\n\n")

          session.run do |msg|
            case msg
            in [:init, data]
              body.write(format_event(:init, data))
            in [:patch, patches]
              body.write(format_event(:patch, patches))
            in [:exception, data]
              body.write(format_event(:exception, data))
            in [:navigate, data]
              body.write(format_event(:navigate, data))
            else
              Console.logger.error(self, "Unhandled message: #{msg.inspect}")
            end
          end

          headers = { "content-type" => "text/event-stream; charset=utf-8" }

          respond(headers:, body:)
        in ["GET", ["__mayu", "live.js"]]
          filename = File.join(__dir__, "client", "dist", "live.js")
          mime_type = MIME::Types.type_for(filename).first
          content_type = mime_type.to_s

          respond(
            body: Protocol::HTTP::Body::File.open(filename),
            headers: {
              "content-type" => content_type
            }
          )
        in ["GET", ["__mayu", "static", filename]]
          public_root = File.join(@environment.root, "public")
          path = File.join(public_root, File.expand_path(filename, "/"))
          body = Protocol::HTTP::Body::File.open(path)
          MIME::Types.type_for(path).first.to_s

          mime_type = MIME::Types.type_for(filename).first
          content_type = mime_type.to_s

          respond(
            body: Protocol::HTTP::Body::File.open(filename),
            headers: {
              "content-type" => content_type
            }
          )
        in ["GET", _path]
          session = Session.new(environment:, path: request.path)
          html = session.initial_render
          headers = { "content-type" => "text/html; charset=utf-8" }
          respond(status: 200, body: [html], headers:)
        else
          respond(status: 400, body: ["Invalid request"])
        end
      end

      private

      sig { params(event: Symbol, data: T.untyped).returns(String) }
      def format_event(event, data)
        "event: #{event}\ndata: #{JSON.generate(data)}\n\n"
      end

      sig { params(id: String, token: String).returns(Session) }
      def fetch_session(id, token)
        @sessions.fetch(session_key(id, token))
      end

      sig { params(session_id: String, token: String).returns(String) }
      def session_key(session_id, token)
        Digest::SHA256.digest(
          Digest::SHA256.digest(session_id) + Digest::SHA256.digest(token)
        )
      end

      sig { params(request: Protocol::HTTP::Request).returns(String) }
      def get_session_token_cookie(request)
        cookies = CGI::Cookie.parse(request.headers["cookie"].to_s)
        cookies
          .fetch("mayu-token") { raise "Cookie mayu-token is not set" }
          .first
      end

      sig do
        params(
          session_id: String,
          session_token: String,
          ttl_seconds: Integer
        ).returns(String)
      end
      def session_token_cookie(session_id, session_token, ttl_seconds: 60 * 60)
        expires = Time.now.utc + ttl_seconds

        cookie = [
          "mayu-token=#{session_token}",
          "path=/__mayu/session/#{session_id}/",
          "expires=#{expires.httpdate}",
          "secure",
          "HttpOnly"
        ].join("; ")
      end

      sig do
        params(status: Integer, headers: Headers, body: Body).returns(
          ResponseArray
        )
      end
      def respond(status: 200, headers: {}, body: [""])
        [status, headers, body]
      end
    end

    extend T::Sig

    sig { params(config: Configuration).returns(Async::Container::Forked) }
    def self.start_dev(config)
      uri =
        URI.for(
          "https",
          nil,
          config.host,
          config.port,
          nil,
          "/",
          nil,
          nil,
          nil
        ).normalize

      ssl_context = dev_ssl_context(config.host)

      server_endpoint =
        Async::HTTP::Endpoint.new(uri, ssl_context:, reuse_port: true)
      bound_endpoint =
        Async { Async::IO::SharedEndpoint.bound(server_endpoint) }.wait

      Console.logger.info(self) { "Starting server on #{uri}" }

      Process.setproctitle("mayu-live file://#{config.root} #{uri}")

      start_container(config, endpoint: bound_endpoint)
    end

    sig { params(host: String).returns(OpenSSL::SSL::SSLContext) }
    def self.dev_ssl_context(host)
      authority = Localhost::Authority.fetch(host)

      authority.server_context.tap do |context|
        context.alpn_select_cb = lambda { |_| "h2" }
        lambda { |protocols| protocols.include?("h2") ? "h2" : nil }

        context.alpn_protocols = ["h2"]
        context.session_id_context = "mayu"
      end
    end

    sig do
      params(config: Configuration, endpoint: Async::IO::Endpoint).returns(
        Async::Container::Forked
      )
    end
    def self.start_container(config, endpoint:)
      Console.logger.info(self, "Starting container...")

      Async::Container::Forked
        .new
        .run(count: config.num_processes, restart: true) do |instance|
          Console.logger.info(self, "Child process started.")

          Async do |task|
            server = setup_server(config, endpoint:)
            server.run

            instance.ready!
            task.children.each(&:wait)
          end
        ensure
          Console.logger.info(self, "Child processes exiting:", $!)
        end
    end

    sig do
      params(config: Configuration, endpoint: Async::IO::Endpoint).returns(
        Async::HTTP::Server
      )
    end
    def self.setup_server(config, endpoint:)
      environment = Mayu::Environment.new(config)

      Routes.log_routes(environment.routes)

      server = Server.new(environment)

      Async::HTTP::Server.for(
        endpoint,
        protocol: Async::HTTP::Protocol::HTTP2,
        scheme: "https"
      ) { |request| Protocol::HTTP::Response[*server.call(request)] }
    end
  end
end

pwd = File.expand_path(File.join(__dir__, "..", "..", "example2"))
config = Mayu::Configuration.load_config(:dev, pwd:)

Mayu::Configuration.log_config(config)

Mayu::Server2.start_dev(config).wait
