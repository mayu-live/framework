# typed: strict
# frozen_string_literal: true

require "async/variable"
require_relative "../event_stream"

module Mayu
  module Server
    class WritableStream
      extend T::Sig

      sig { params(body: Async::HTTP::Body::Writable).void }
      def initialize(body)
        @body = body
        @deflate =
          T.let(
            Zlib::Deflate.new(
              Zlib::BEST_COMPRESSION,
              -Zlib::MAX_WBITS,
              Zlib::MAX_MEM_LEVEL,
              Zlib::HUFFMAN_ONLY
            ),
            Zlib::Deflate
          )

        @wrapper = T.let(EventStream::Wrapper.new, EventStream::Wrapper)
      end

      sig { params(obj: T.untyped).void }
      def write(obj)
        obj
          .then { @wrapper.pack(_1.to_a) }
          .then { @deflate.deflate(_1, Zlib::SYNC_FLUSH) }
          .then { @body.write(_1) }
      end

      sig { returns(T::Boolean) }
      def closed?
        @body.closed?
      end

      sig { void }
      def close
        @body.write(@deflate.flush(Zlib::FINISH))
        @deflate.close
        @body.close
      end
    end

    class App
      extend T::Sig

      PING_INTERVAL = 2 # seconds
      NANOID_RE = /[\w-]{21}/

      MIME_TYPES =
        T.let(
          {
            eventstream: "application/vnd.mayu.eventstream",
            session: "application/vnd.mayu.session"
          },
          T::Hash[Symbol, String]
        )

      class NotFoundError < StandardError
      end
      class CookieNotSetError < StandardError
      end
      class InvalidTokenError < StandardError
      end
      class InvalidMethodError < StandardError
      end
      class SessionAlreadyResumedError < StandardError
      end
      class SessionNotFoundError < StandardError
      end
      class ServerIsShuttingDownError < StandardError
      end

      sig { params(environment: Environment).void }
      def initialize(environment:)
        @environment = environment
        @metrics = T.let(environment.metrics, AppMetrics)
        @barrier = T.let(Async::Barrier.new, Async::Barrier)
        @stop = T.let(Async::Variable.new, Async::Variable)
        @sessions = T.let({}, T::Hash[String, Session])
      end

      sig { void }
      def clear_expired_sessions!
        old_size = @sessions.size

        @sessions.delete_if do |id, session|
          next unless session.expired?(20)

          Console.logger.warn(self, "Session #{session.id} timed out")
          session.stop!
          @metrics.session_timeout_count.increment
          true
        end

        unless @sessions.size == old_size
          Console.logger.warn(self, "Session count: #{@sessions.size}")
        end

        @metrics.session_count.set(@sessions.size)
      end

      sig { void }
      def stop
        @stop.resolve(true)
        @barrier.wait
        Console.logger.info(self, "Stopped sessions")
      end

      sig { void }
      def close
        @barrier.wait
      end

      sig { returns(Integer) }
      def time_ping_value
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond).to_i &
          0x0fffffff
      end

      sig do
        params(request: Protocol::HTTP::Request).returns(
          Protocol::HTTP::Response
        )
      end
      def call(request)
        # Console.logger.info(self, "#{request.method} #{request.path}")

        raise_if_shutting_down!

        case request.path.delete_prefix("/").split("/")
        in ["__mayu", "session", NANOID_RE => session_id, *rest]
          handle_session_post(request, session_id, rest)
        in ["index.js"]
          body = File.read(File.join(__dir__, "client", "dist", "live.js"))
          Protocol::HTTP::Response[
            200,
            { "content-type": "application/javascript" },
            [body]
          ]
        in ["favicon.ico" | "robots.txt" => filename]
          # Idea: Maybe it would be possible to create an asset from the favicon and redirect?
          absolute_path =
            File.join(@environment.root, "app", filename.sub(/\.ico$/, ".png"))
          send_static_file(absolute_path, cache: false)
        in ["__mayu", "runtime", *path]
          accept_encodings = request.headers["accept-encoding"].to_s.split(", ")

          filename = File.join(*path)

          if filename == "entries.json"
            return Protocol::HTTP::Response[403, {}, ["forbidden"]]
          end

          absolute_path =
            File.join(
              @environment.js_runtime_path,
              File.expand_path(filename, "/")
            )

          send_static_file(absolute_path, accept_encodings:)
        in ["__mayu", "static", filename]
          unless @environment.config.use_bundle
            @environment.resources.generate_assets(@environment.path(:assets))
          end

          accept_encodings = request.headers["accept-encoding"].to_s.split(", ")

          send_static_file(
            File.join(
              @environment.path(:assets),
              File.expand_path(filename, "/")
            ),
            accept_encodings:
          )
        in ["__mayu", *]
          raise NotFoundError,
                "Resource not found at: #{request.method} #{request.path}"
        in [*] if request.method == "GET"
          raise_if_shutting_down!

          handle_session_init(request)
        else
          Protocol::HTTP::Response[404, {}, ["not found"]]
        end
      rescue NotFoundError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          404,
          { "content-type": "text/plain" },
          [e.message.to_s]
        ]
      rescue CookieNotSetError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          403,
          { "content-type": "text/plain" },
          ["missing session cookie"]
        ]
      rescue SessionNotFoundError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          404,
          { "content-type": "text/plain" },
          ["session not found"]
        ]
      rescue Mayu::MessageCipher::DecryptError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          403,
          { "content-type": "text/plain" },
          ["decrypt error"]
        ]
      rescue Mayu::MessageCipher::ExpiredError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          403,
          { "content-type": "text/plain" },
          ["session expired"]
        ]
      rescue InvalidTokenError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          403,
          { "content-type": "text/plain" },
          ["invalid token"]
        ]
      rescue SessionAlreadyResumedError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          409,
          { "content-type": "text/plain" },
          ["already resumed"]
        ]
      rescue Session::AlreadyRunningError
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          409,
          { "content-type": "text/plain" },
          ["already running"]
        ]

        # https://fly.io/docs/reference/fly-replay/#fly-replay
      rescue ServerIsShuttingDownError
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          503,
          { "fly-replay": "elsewhere=true" },
          ["Server is shutting down"]
        ]
      rescue InvalidMethodError => e
        Console.logger.error(self, e)
        Protocol::HTTP::Response[
          405,
          { "content-type": "text/plain" },
          ["method not allowed"]
        ]
      rescue => e
        Console.logger.error(self, e)
        Protocol::HTTP::Response[500, {}, "error"]
      end

      sig { void }
      def rerender
        @sessions.values.each(&:rerender)
      end

      sig do
        params(
          id: String,
          request: Protocol::HTTP::Request,
          resume: T::Boolean
        ).returns(Session)
      end
      def get_session(id, request, resume: false)
        session = load_session(id, resume ? request.read.to_s : "")

        if session.authorized?(get_token_cookie(request))
          session
        else
          raise InvalidTokenError
        end
      end

      sig { void }
      def raise_if_shutting_down!
        raise ServerIsShuttingDownError if @stop.resolved?
      end

      sig do
        params(
          request: Protocol::HTTP::Request,
          session_id: String,
          path: T::Array[String]
        ).returns(Protocol::HTTP::Response)
      end
      def handle_session_post(request, session_id, path)
        raise InvalidMethodError unless request.method == "POST"

        if ["resume"] === path
          body = Async::HTTP::Body::Writable.new
          session = get_session(session_id, request, resume: true)
          run_event_stream(session, body:)

          return(
            Protocol::HTTP::Response[
              200,
              { "content-type": MIME_TYPES[:eventstream] },
              body
            ]
          )
        end

        session = get_session(session_id, request, resume: false)
        session.activity!

        case path
        in ["init"]
          body = Async::HTTP::Body::Writable.new
          run_event_stream(session, body:)
          Protocol::HTTP::Response[
            200,
            { "content-type": MIME_TYPES[:eventstream] },
            body
          ]
        in ["ping"]
          body = JSON.parse(request.read.to_s)
          pong = body["pong"].to_f
          ping = body["ping"]
          time = time_ping_value
          server_pong = time_ping_value - body["pong"].to_f
          # Console.logger.info(
          #   self,
          #   format("Session #{session.id} ping: %.2f ms", server_pong)
          # )
          headers = {
            "content-type": "application/json",
            "set-cookie": token_cookie(session)
          }
          session.log.push(
            :pong,
            pong: ping,
            server: server_pong,
            region: @environment.config.instance.region,
            instance: @environment.config.instance.alloc_id.split("-", 2).first
          )
          Protocol::HTTP::Response[200, headers, [JSON.generate(ping)]]
        in ["navigate"]
          @environment.metrics.session_navigate_count.increment()
          path = request.read.force_encoding("utf-8")
          session.handle_callback("navigate", { path: })
          Protocol::HTTP::Response[200, headers, ["ok"]]
        in ["callback", String => callback_id]
          session.handle_callback(callback_id, JSON.parse(request.read))
          headers = { "set-cookie": token_cookie(session) }
          Protocol::HTTP::Response[200, headers, ["ok"]]
        end
      end

      sig do
        params(request: Protocol::HTTP::Request).returns(
          Protocol::HTTP::Response
        )
      end
      def handle_session_init(request)
        Console.logger.info(self) { "Init session: #{request.path}" }
        session = Session.new(environment: @environment, path: request.path)
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
          "</__mayu/runtime/#{@environment.init_js}##{session.id}>; rel=preload; as=script; crossorigin=same-origin; fetchpriority=high",
          *stylesheets.map { "<#{_1}>; rel=preload; as=style" }
        ].join(", ")

        headers["set-cookie"] = token_cookie(session)

        @sessions.store(session.id, session)

        @environment.metrics.session_init_count.increment()

        Protocol::HTTP::Response[200, headers, body]
      end

      sig do
        params(session: Session, body: Async::HTTP::Body::Writable).returns(
          Async::Task
        )
      end
      def run_event_stream(session, body:)
        @barrier.async do |task|
          session.activity!

          writable_stream = WritableStream.new(body)

          Console.logger.info(self, "Streaming events to session #{session.id}")

          barrier = Async::Barrier.new
          stop_notification = Async::Notification.new

          task.async do
            @stop.wait
            stop_notification.signal
          end

          session_task =
            barrier.async do
              session
                .run do |message|
                  case message
                  in [event, payload]
                    session.log.push(:"session.#{event}", payload)
                  end
                end
                .wait
            ensure
              stop_notification.signal
            end

          ping_task =
            barrier.async do
              loop do
                sleep PING_INTERVAL
                session.log.push(:ping, time_ping_value)
              end
            end

          message_task =
            barrier.async do |subtask|
              loop { writable_stream.write(session.log.pop.to_a) }
            ensure
              barrier.stop
            end

          stop_notification.wait

          barrier.stop
          perform_transfer(session, writable_stream)
          task.stop
        end
      end

      private

      sig { params(session_id: String, body: String).returns(Session) }
      def load_session(session_id, body)
        if body.empty?
          return(
            @sessions.fetch(session_id) do
              raise SessionNotFoundError, "Session not found: #{session_id}"
            end
          )
        end

        @environment.message_cipher.load(body) => String => dumped
        session = Session.restore(environment: @environment, dumped:)
        @sessions.store(session.id, session)
      end

      sig do
        params(
          session: Session,
          writable_stream: WritableStream,
          task: Async::Task
        ).void
      end
      def perform_transfer(session, writable_stream, task: Async::Task.current)
        return if writable_stream.closed?

        Console.logger.info(self, "Session #{session.id}: Transferring")

        writable_stream.write(
          EventStream::Message.new(
            :"session.transfer",
            EventStream::Blob.new(
              @environment.message_cipher.dump(
                Session::SerializedSession.dump_session(session)
              )
            )
          ).to_a
        )

        # Sleep a little bit so that the message
        # gets sent before the body closes...
        # This is not ideal, heh..
        sleep 0.1
        writable_stream.close
      end

      sig do
        params(
          full_path: String,
          accept_encodings: T::Array[String],
          cache: T::Boolean
        ).returns(Protocol::HTTP::Response)
      end
      def send_static_file(full_path, accept_encodings: [], cache: true)
        unless File.exist?(full_path)
          return Protocol::HTTP::Response[404, {}, ["not found"]]
        end

        mime_type = MIME::Types.type_for(full_path).first
        content_type = mime_type.to_s

        headers = { "content-type" => content_type }

        headers["cache-control"] = "public, max-age=604800" if cache

        if accept_encodings.include?("br")
          if File.exist?(full_path + ".br")
            full_path += ".br"
            headers["content-encoding"] = "br"
          end
        end

        Protocol::HTTP::Response[
          200,
          headers,
          Protocol::HTTP::Body::File.open(full_path)
        ]
      end

      sig { params(request: Protocol::HTTP::Request).returns(String) }
      def get_token_cookie(request)
        CGI::Cookie
          .parse(request.headers["cookie"].to_s)
          .fetch("mayu-token") do
            raise CookieNotSetError, "Cookie #{_1} is not set"
          end
          .first
          .to_s
          .tap { Session.validate_token!(_1) }
      end

      sig { params(session: Session, ttl_seconds: Integer).returns(String) }
      def token_cookie(session, ttl_seconds: 60)
        expires = Time.now.utc + ttl_seconds

        [
          "mayu-token=#{session.token}",
          "path=/__mayu/session/#{session.id}/",
          "expires=#{expires.httpdate}",
          "secure",
          "HttpOnly",
          "SameSite=Strict"
        ].join("; ")
      end
    end
  end
end
