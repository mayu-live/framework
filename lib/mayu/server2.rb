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
require_relative "environment"
require_relative "session"

module Mayu
  module Server2
    class Server
      extend T::Sig

      Status = T.type_alias { Integer }
      Headers = T.type_alias { T::Hash[String, String] }
      Body = T.type_alias { T.any(String, Async::HTTP::Body::Writable) }
      ResponseArray = T.type_alias { [Status, Headers, [Body]] }

      sig { returns(Environment) }
      attr_reader :environment

      sig { params(environment: Environment).void }
      def initialize(environment)
        @environment = environment
        @sessions = T.let({}, T::Hash[String, Session])
      end

      sig { params(session_id: String, token: String).returns(String) }
      def session_key(session_id, token)
        Digest::SHA256.digest(
          Digest::SHA256.digest(session_id) + Digest::SHA256.digest(token)
        )
      end

      sig { params(request: Protocol::HTTP::Request).returns(ResponseArray) }
      def call(request)
        case [request.method, request.path.delete_prefix("/").split("/")]
        in ["POST", ["__mayu", "session", session_id, "resume"]]
          token =
            CGI::Cookie.parse(request.headers.fetch("cookie", "")).fetch(
              "mayu-token"
            )
          data = @environment.message_cipher.load(request.body.to_s)
          session = Session.restore(environment:, data:)
          @sessions[
            session_key(session_id: session.id, session_token: session.token)
          ] = session
        in ["POST", ["__mayu", "session", session_id, "callback", callback_id]]
          token =
            CGI::Cookie.parse(request.headers.fetch("cookie", "")).fetch(
              "mayu-token"
            )
          session = @sessions.fetch(session_key(session_id, token))
          session.handle_callback(callback_id)
        in ["GET", []]
          respond(
            headers: {
              "content-type" => "text/plain"
            },
            body: "Hello world"
          )
        end

        if request.method == "GET"
          Session.init(environment:, path: request.path)
        else
          respond(status: 400, body: "Invalid request")
        end
      end

      private

      sig do
        params(status: Integer, headers: Headers, body: Body).returns(
          ResponseArray
        )
      end
      def respond(status: 200, headers: {}, body: "")
        [status, headers, [body]]
      end

      sig do
        params(
          headers: Headers,
          task: Async::Task,
          block: T.proc.params(arg0: Async::HTTP::Body::Writable).void
        ).returns(ResponseArray)
      end
      def stream(headers: {}, task: Async::Task.current, &block)
        body = Async::HTTP::Body::Writable.new

        task.async { yield body }

        respond(headers:, body:)
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
      config =
        Mayu::Environment::Config.new(
          SECRET_KEY: "development",
          FLY_APP_NAME: "mayu-dev",
          FLY_ALLOC_ID: SecureRandom.uuid.gsub(/\h/, "0"),
          FLY_REGION: "dev"
        )
      root = File.expand_path(File.join(__dir__, "..", "..", "example"))

      environment = Mayu::Environment.new(root:, config:, hot_reload: true)

      server = Server.new(environment)

      Async::HTTP::Server.for(
        endpoint,
        protocol: Async::HTTP::Protocol::HTTP2,
        scheme: "https"
      ) { |request| Protocol::HTTP::Response[*server.call(request)] }
    end
  end
end

Mayu::Server2.start_dev(port: 1234, count: 2).wait
