# typed: strict
# frozen_string_literal: true

require "async/variable"
require_relative "../event_stream"
require_relative "file_server"
require_relative "errors"

module Mayu
  module Server
    class App
      extend T::Sig

      DEV_ASSETS_TIMEOUT_SECONDS = 4
      DEV_ASSETS_RETRY_AFTER_SECONDS = 2
      PING_INTERVAL = 2 # seconds
      NANOID_RE = /[\w-]{21}/

      PREFER_LANGUAGE_COOKIE = "mayu-prefer-language"
      TOKEN_COOKIE = "mayu-token"

      MIME_TYPES =
        T.let(
          {
            eventstream: "application/vnd.mayu.eventstream",
            session: "application/vnd.mayu.session"
          },
          T::Hash[Symbol, String]
        )

      sig { params(environment: Environment).void }
      def initialize(environment:)
        @environment = environment
        @metrics = T.let(environment.metrics, AppMetrics)
        @barrier = T.let(Async::Barrier.new, Async::Barrier)
        @stop = T.let(Async::Variable.new, Async::Variable)
        @sessions = T.let({}, T::Hash[String, Session])

        @runtime_assets =
          T.let(FileServer.new(@environment.js_runtime_path), FileServer)
        @static_assets =
          T.let(FileServer.new(@environment.path(:assets)), FileServer)
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
        # The following line generates very noisy logs,
        # but can be useful when debugging.
        # Console.logger.info(self, "#{request.method} #{request.path}")

        Errors.handle_exceptions { handle_request(request) }
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
        cookie_value = get_token_cookie_value(request)

        if session.authorized?(cookie_value)
          session
        else
          raise Errors::UnauthorizedSessionCookie,
                "session with id #{id} had wrong value #{cookie_value.inspect}"
        end
      end

      sig do
        params(request: Protocol::HTTP::Request).returns(
          Protocol::HTTP::Response
        )
      end
      def handle_request(request)
        # FIXME: raise_if_shutting_down! should only prevent the following:
        # * starting new sessions
        # * updating sessions that have been transferred
        # * updating sessions that have been paused for transferring
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
        in ["robots.txt"]
          Protocol::HTTP::Response[
            200,
            { "content-type" => "text/plain; charset=utf-8" },
            File.read(File.join(@environment.root, "app", "robots.txt"))
          ]
        in ["favicon.ico"]
          # Idea: Maybe it would be possible to create
          # an asset from the favicon and redirect to the asset?
          Protocol::HTTP::Response[
            200,
            { "content-type" => "image/png" },
            Protocol::HTTP::Body::File.open(
              File.join(@environment.root, "app", "favicon.png")
            )
          ]
        in ["__mayu", "status"]
          Protocol::HTTP::Response[200, {}, "ok"]
        in ["__mayu", "runtime", *path]
          accept_encodings = request.headers["accept-encoding"].to_s.split(", ")

          filename = File.join(*path)

          if filename == "entries.json"
            return Protocol::HTTP::Response[403, {}, ["forbidden"]]
          end

          @runtime_assets.serve(filename, accept_encodings:)
        in ["__mayu", "static", filename]
          if @environment.config.server.generate_assets
            begin
              @environment.resources.wait_for_asset(
                filename,
                timeout: DEV_ASSETS_TIMEOUT_SECONDS
              )
            rescue Async::TimeoutError => e
              Console.logger.warn(
                self,
                "Asset #{filename} could not be generated in time"
              )
              return(
                Protocol::HTTP::Response[
                  503,
                  { "retry-after" => DEV_ASSETS_RETRY_AFTER_SECONDS },
                  ["asset could not be generated in time"]
                ]
              )
            end
          end

          accept_encodings = request.headers["accept-encoding"].to_s.split(", ")

          @static_assets.serve(filename, accept_encodings:)
        in ["__mayu", *]
          raise Errors::FileNotFound,
                "Resource not found at: #{request.method} #{request.path}"
        in [*] if request.method == "GET"
          raise_if_shutting_down!

          handle_session_init(request)
        else
          Protocol::HTTP::Response[404, {}, ["not found"]]
        end
      end

      sig { void }
      def raise_if_shutting_down!
        raise Errors::ServerIsShuttingDown if @stop.resolved?
      end

      sig do
        params(
          request: Protocol::HTTP::Request,
          session_id: String,
          path: T::Array[String]
        ).returns(Protocol::HTTP::Response)
      end
      def handle_session_post(request, session_id, path)
        raise Errors::InvalidMethod unless request.method == "POST"

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
            "set-cookie": set_token_cookie_value(session)
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
          prefer_language = session.prefer_language

          session.handle_callback(
            callback_id,
            JSON.parse(request.read, symbolize_names: true)
          )

          headers = Protocol::HTTP::Headers.new

          unless session.prefer_language == prefer_language
            headers.add(
              "set-cookie",
              set_prefer_language_cookie_value(session.prefer_language.to_s)
            )
          end

          headers.add("set-cookie", set_token_cookie_value(session))
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

        validate_header!(
          request.headers,
          "sec-fetch-mode",
          "navigate"
        ) do |value|
          raise Errors::InvalidSecFetchHeader,
                "Expected sec-fetch-mode to equal navigate but got #{value.inspect}"
        end

        validate_header!(
          request.headers,
          "sec-fetch-dest",
          "document"
        ) do |value|
          raise Errors::InvalidSecFetchHeader,
                "Expected sec-fetch-dest to equal document but got #{value.inspect}"
        end

        cookies = get_cookies(request)

        session =
          Session.new(
            environment: @environment,
            path: request.path,
            headers: request.headers.to_h.freeze,
            prefer_language: cookies[PREFER_LANGUAGE_COOKIE]
          )
        body = Async::HTTP::Body::Writable.new

        headers = {
          "content-type" => "text/html; charset=utf-8",
          "cache" => "no-cache"
        }

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

        headers["set-cookie"] = set_token_cookie_value(session)

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

          stream = EventStream::Writable.new(body)

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
              loop { stream.write(session.log.pop.to_a) }
            ensure
              barrier.stop
            end

          stop_notification.wait

          barrier.stop
          perform_transfer(session, stream)
          task.stop
        end
      end

      private

      sig do
        params(
          headers: Protocol::HTTP::Headers,
          name: String,
          expected_value: String,
          block: T.proc.params(arg0: String).void
        ).void
      end
      def validate_header!(headers, name, expected_value, &block)
        if actual_value = headers[name]
          yield actual_value.to_s unless actual_value.to_s == expected_value
        end
      end

      sig { params(session_id: String, body: String).returns(Session) }
      def load_session(session_id, body)
        if body.empty?
          return(
            @sessions.fetch(session_id) do
              raise Errors::SessionNotFound, "Session not found: #{session_id}"
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
          stream: EventStream::Writable,
          task: Async::Task
        ).void
      end
      def perform_transfer(session, stream, task: Async::Task.current)
        return if stream.closed?

        Console.logger.info(self, "Session #{session.id}: Transferring")

        stream.write(
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
        # This is not ideal though, it would be better
        # maybe if the client would acknowledge that they
        # have received it?
        sleep 0.1
        stream.close
      end

      sig do
        params(request: Protocol::HTTP::Request).returns(
          T::Hash[String, String]
        )
      end
      def get_cookies(request)
        Array(request.headers["cookie"]).each_with_object({}) do |str, obj|
          key, value = str.split("=", 2)
          obj[key] = value
        end
      end

      sig { params(language: String).returns(String) }
      def set_prefer_language_cookie_value(language)
        return "#{PREFER_LANGUAGE_COOKIE}=; max-age=0" if language.empty?

        [
          "#{PREFER_LANGUAGE_COOKIE}=#{language}",
          "expires=",
          "path=/",
          "secure",
          "SameSite=Strict"
        ].join("; ")
      end

      sig { params(request: Protocol::HTTP::Request).returns(String) }
      def get_token_cookie_value(request)
        get_cookies(request)
          .fetch(TOKEN_COOKIE) { raise Errors::CookieNotSet }
          .to_s
          .tap { Session.validate_token!(_1) }
      end

      sig { params(session: Session, ttl_seconds: Integer).returns(String) }
      def set_token_cookie_value(session, ttl_seconds: 60)
        [
          "#{TOKEN_COOKIE}=#{session.token}",
          "path=/__mayu/session/#{session.id}/",
          "max-age=#{ttl_seconds}",
          "secure",
          "HttpOnly",
          "SameSite=Strict"
        ].join("; ")
      end
    end
  end
end
