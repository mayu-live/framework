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

      UUIDv4 =
        /
          \A
            [[:xdigit:]]{8}
            -
            [[:xdigit:]]{4}
            -
            4
            [[:xdigit:]]{3}
            -
            [89ab]
            [[:xdigit:]]{3}
            -
            [[:xdigit:]]{12}
          \z
        /x

      Status = T.type_alias { Integer }
      Headers =
        T.type_alias { T::Hash[String, T.any(String, T::Array[String])] }
      Body =
        T.type_alias do
          T.any(
            [String],
            Async::HTTP::Body::Writable,
            Protocol::HTTP::Body::File
          )
        end
      ResponseArray = T.type_alias { [Status, Headers, Body] }

      class SessionNotFoundError < StandardError
      end

      sig { returns(Environment) }
      attr_reader :environment

      sig { params(environment: Environment).void }
      def initialize(environment)
        @environment = environment
        @sessions = T.let({}, T::Hash[String, Session])
      end

      sig { void }
      def rerender
        @sessions.values.each(&:rerender)
      end

      sig { params(request: Protocol::HTTP::Request).returns(ResponseArray) }
      def call(request)
        Console.logger.info(self) { "#{request.method} #{request.path}" }

        case [request.method, request.path.delete_prefix("/").split("/")]
        in ["POST", ["__mayu", "session", "resume", *_rest]]
          handle_resume_session(request)
        in ["POST", ["__mayu", "session", UUIDv4 => session_id, *args]]
          handle_session_post(request, session_id, args)
        in ["GET", ["__mayu", "session", UUIDv4 => session_id, "events"]]
          handle_session_sse(request, session_id)
        in ["GET", ["__mayu", "static", filename]]
          @environment.resources.generate_assets(@environment.path(:assets))

          accept_encodings = request.headers["accept_encoding"].to_s.split(", ")

          send_static_file(
            File.join(
              @environment.path(:assets),
              File.expand_path(filename, "/")
            ),
            accept_encodings:
          )
        in ["GET", _path]
          handle_init_session(request)
        else
          respond(status: 400, body: ["Invalid request"])
        end
      rescue SessionNotFoundError => e
        Console.logger.error(self, e)
        respond(status: 404, body: ["Session not found"])
      end

      private

      sig { params(request: Protocol::HTTP::Request).returns(ResponseArray) }
      def handle_init_session(request)
        session = Session.new(environment:, path: request.path)
        session.initial_render => { html:, stylesheets: }

        links = [
          "</__mayu/static/#{environment.init_js}>; rel=preload; as=script; crossorigin=anonymous; fetchpriority=high",
          *stylesheets.map { "<#{_1}>; rel=preload; as=style" }
        ].join(", ")
        headers = {
          "content-type" => "text/html; charset=utf-8",
          "link" => links
        }
        respond(status: 200, body: [html], headers:)
      end

      sig { params(request: Protocol::HTTP::Request).returns(ResponseArray) }
      def handle_resume_session(request)
        dumped = @environment.message_cipher.load(request.read)
        session = Session.restore(environment:, dumped:)

        @sessions[session_key(session.id, session.token)] = session

        headers = {
          "content-type" => "text/plain",
          "set-cookie" => session_token_cookie(session.id, session.token)
        }

        respond(headers:, body: [session.id])
      rescue MessageCipher::Error => e
        Console.logger.error(self, e.class.name, e.message)
        respond(status: 500, body: ["error"])
      end

      sig do
        params(
          request: Protocol::HTTP::Request,
          session_id: String,
          args: T::Array[String]
        ).returns(ResponseArray)
      end
      def handle_session_post(request, session_id, args)
        session = fetch_session(session_id, get_session_token_cookie(request))

        case args
        in ["ping"]
          timestamp = request.read.to_i
          session.handle_callback("ping", { timestamp: })
        in ["navigate"]
          path = request.read
          session.handle_callback("navigate", { path: })
        in ["callback", Component::HandlerRef::ID_FORMAT => callback_id]
          payload = JSON.parse(request.read)
          session.handle_callback(callback_id, payload)
        end

        respond(
          headers: {
            "content-type" => "text/plain",
            "set-cookie" => session_token_cookie(session.id, session.token)
          },
          body: ["ok"]
        )
      end
      sig do
        params(request: Protocol::HTTP::Request, session_id: String).returns(
          ResponseArray
        )
      end
      def handle_session_sse(request, session_id)
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
          in [:pong, data]
            body.write(
              format_event(
                :pong,
                { timestamp: data, region: environment.config.region }
              )
            )
          in [:navigate, data]
            body.write(format_event(:navigate, data))
          else
            Console.logger.error(self, "Unhandled message: #{msg.inspect}")
          end
        end

        headers = { "content-type" => "text/event-stream; charset=utf-8" }

        respond(headers:, body:)
      end

      sig do
        params(full_path: String, accept_encodings: T::Array[String]).returns(
          ResponseArray
        )
      end
      def send_static_file(full_path, accept_encodings: [])
        mime_type = MIME::Types.type_for(full_path).first
        content_type = mime_type.to_s

        headers = {
          "content-type" => content_type,
          "cache-control" => "public, max-age=604800"
        }

        if accept_encodings.include?("br")
          if File.exists?(full_path + ".br")
            full_path += ".br"
            headers["content-encoding"] = "br"
          end
        end

        respond(body: Protocol::HTTP::Body::File.open(full_path), headers:)
      end

      sig { params(event: Symbol, data: T.untyped).returns(String) }
      def format_event(event, data)
        "event: #{event}\ndata: #{JSON.generate(data)}\n\n"
      end

      sig { params(id: String, token: String).returns(Session) }
      def fetch_session(id, token)
        @sessions.fetch(session_key(id, token)) do
          raise SessionNotFoundError,
                "Session not found or invalid token: #{id}"
        end
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
      def session_token_cookie(session_id, session_token, ttl_seconds: 60)
        expires = Time.now.utc + ttl_seconds

        cookie = [
          "mayu-token=#{session_token}",
          "path=/__mayu/session/#{session_id}/",
          "expires=#{expires.httpdate}",
          "secure",
          "HttpOnly",
          "SameSite=Strict"
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

      environment.resources.start_hot_swap do
        puts "Updated"
               .chars
               .map
               .with_index { |ch, i|
                 t = Time.now.to_f
                 r, g, b =
                   3
                     .times
                     .map { _1 / 3.0 * Math::PI }
                     .map { _1 + t }
                     .map { _1 + i / 10.0 }
                     .map { Math.sin(_1)**2 }
                     .map { _1 * 255 }
                     .map(&:to_i)

                 format("\e[38;2;%d;%d;%dm%s", r, g, b, ch)
               }
               .join + "\e[0m"

        server.rerender
      end

      Async::HTTP::Server.for(
        endpoint,
        protocol: Async::HTTP::Protocol::HTTP2,
        scheme: "https"
      ) { |request| Protocol::HTTP::Response[*server.call(request)] }
    end
  end
end

if $0 == __FILE__
  pwd = File.expand_path(File.join(__dir__, "..", "..", "example2"))
  config = Mayu::Configuration.load_config(:dev, pwd:)

  Mayu::Configuration.log_config(config)

  Mayu::Server2.start_dev(config).wait
end
