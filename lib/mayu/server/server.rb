# typed: strict
# frozen_string_literal: true

require_relative "sessions"
require "protocol/http/body/file"

module Mayu
  module Server
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

      sig { returns(Environment) }
      attr_reader :environment

      sig { params(environment: Environment).void }
      def initialize(environment)
        @environment = environment
        @sessions = T.let(Sessions.new, Sessions)
        @timeouts = T.let({}, T::Hash[String, Async::Task])
      end

      sig { void }
      def rerender
        @sessions.rerender
      end

      sig { params(request: Protocol::HTTP::Request).returns(ResponseArray) }
      def call(request)
        case [request.method, request.path.delete_prefix("/").split("/")]
        in ["POST", ["__mayu", "session", "resume", *_rest]]
          handle_resume_session(request)
        in ["POST", ["__mayu", "session", UUIDv4 => session_id, *args]]
          handle_session_post(request, session_id, args)
        in ["GET", ["__mayu", "session", UUIDv4 => session_id, "events"]]
          handle_session_sse(request, session_id)
        in ["GET", ["__mayu", "static", filename]]
          @environment.resources.generate_assets(@environment.path(:assets))

          accept_encodings = request.headers["accept-encoding"].to_s.split(", ")

          send_static_file(
            File.join(
              @environment.path(:assets),
              File.expand_path(filename, "/")
            ),
            accept_encodings:
          )
        in ["GET", ["favicon.ico"]]
          respond(status: 404, body: ["no favicon"])
        in ["GET", ["__mayu.serviceWorker.js"]]
          respond(status: 404, body: ["no service worker"])
        in ["GET", _path]
          handle_init_session(request)
        else
          Console
            .logger
            .error(self) do
              "Invalid request: #{request.method} #{request.path}"
            end
          respond(status: 400, body: ["Invalid request"])
        end
      rescue Sessions::NotFoundError => e
        Console.logger.error(self, e)
        respond(status: 404, body: ["Session not found"])
      end

      private

      sig { params(request: Protocol::HTTP::Request).returns(ResponseArray) }
      def handle_init_session(request)
        Console.logger.info(self) { "Init session: #{request.path}" }
        session = Session.new(environment:, path: request.path)
        body = Async::HTTP::Body::Writable.new

        headers = { "content-type" => "text/html; charset=utf-8" }

        accept_encodings = request.headers["accept-encoding"].to_s.split(", ")

        writer =
          if accept_encodings.include?("br")
            headers["content-encoding"] = "br"
            Brotli::Writer.new(body)
          else
            body
          end

        session.initial_render(writer) => { stylesheets: }

        headers["link"] = [
          "</__mayu/static/#{environment.init_js}>; rel=preload; as=script; crossorigin=anonymous; fetchpriority=high",
          *stylesheets.map { "<#{_1}>; rel=preload; as=style" }
        ].join(", ")

        respond(status: 200, headers:, body:)
      end

      sig { params(request: Protocol::HTTP::Request).returns(ResponseArray) }
      def handle_resume_session(request)
        dumped = @environment.message_cipher.load(request.read)
        session = Session.restore(environment:, dumped:)

        @sessions.add(session)

        headers = {
          "content-type" => "text/plain",
          "set-cookie" => session_token_cookie(session.id, session.token)
        }

        respond(headers:, body: [session.id])
      rescue MessageCipher::Error => e
        Console.logger.error(self, e)
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
        session = @sessions.fetch(session_id, get_session_token_cookie(request))

        case args
        in ["ping"]
          timestamp = request.read.to_i
          session.handle_callback("ping", { timestamp: })
        in ["navigate"]
          path = request.read
          session.handle_callback("navigate", { path: })
        in ["callback", Component::HandlerRef::ID_FORMAT => callback_id]
          @environment.metrics.session_callbacks.increment()

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
        params(
          request: Protocol::HTTP::Request,
          session_id: String,
          task: Async::Task
        ).returns(ResponseArray)
      end
      def handle_session_sse(request, session_id, task: Async::Task.current)
        session = @sessions.fetch(session_id, get_session_token_cookie(request))
        body = Async::HTTP::Body::Writable.new

        body.write(
          "retry: #{@environment.config.server.event_source_retry_ms}\n\n"
        )

        task.async do
          @timeouts.delete(session_id)&.stop

          session
            .run do |msg|
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
                    {
                      timestamp: data,
                      region: environment.config.instance.region
                    }
                  )
                )
              in [:navigate, data]
                body.write(format_event(:navigate, data))
              else
                Console.logger.error(self, "Unknown message: #{msg.inspect}")
              end
            end
            .wait
        ensure
          @timeouts[session.id] = task.async do
            Console.logger.warn(self, "Disconnected: #{session.id}")
            sleep 5
            Console.logger.warn(self, "Timed out: #{session.id}")
            @sessions.delete(session.id, session.token)
          ensure
            @timeouts.delete(session.id)
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
          if File.exist?(full_path + ".br")
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
  end
end
