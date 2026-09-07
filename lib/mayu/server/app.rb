# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "request_refinements"
require_relative "cookies"
require_relative "event_stream"
require_relative "static_files"

require_relative "../environment"
require_relative "../session"
require_relative "../session/store"
require_relative "../klenod"

module Mayu
  class Server
    class App
      using RequestRefinements

      ALLOW_HEADERS =
        Ractor.make_shareable(
          {
            "access-control-allow-methods": "GET, POST, OPTIONS",
            "access-control-allow-headers": %w[
              content-type
              accept
              accept-encoding
            ].join(", ")
          }
        )

      ASSET_CACHE_CONTROL = [
        "public",
        "max-age=#{7 * 24 * 60 * 60}",
        "immutable"
      ].join(", ").freeze

      ASSET_CACHE_CONTROL_HEADER = {
        "cache-control": ASSET_CACHE_CONTROL
      }.freeze

      def initialize(environment)
        @environment = environment
        @stopping = false
        @sessions = Session::Store.new(metrics: @environment.metrics)
        @body_barrier = Async::Barrier.new
        @cookies =
          Cookies.new(
            timeout_seconds: environment.config.server.cookie_timeout_seconds
          )
        @client_files = StaticFiles.new(@environment.client_path)
        @sessions.start_cleanup_task(
          environment.config.server.session_timeout_seconds
        )
      end

      SESSION_PATH_RE = %r{\A/.mayu/session/(?<session_id>[[:alnum:]]+)\z}

      def call(request)
        return text_response(503, "Server is stopping") if @stopping

        # puts "\e[3;33m #{request.method} #{request.path} \e[0m"

        case request
        in path: "/favicon.ico"
          handle_favicon(request)
        in { path: "/.mayu", method: "OPTIONS" }
          handle_options(request)
        in { method: "GET", path: "/.mayu/init.js" }
          handle_init_js(request)
        in path: %r{\A/.mayu/runtime/.+\.js(\.map)?}
          handle_script(request)
        in { path: %r{\A/\.mayu/assets/(.+)\z}, method: "GET" }
          handle_asset(request)
        in { method: "GET", path: SESSION_PATH_RE }
          handle_session_resume(request, $~[:session_id])
        in { method: "POST", path: SESSION_PATH_RE }
          handle_session_transfer(request, $~[:session_id])
        in { method: "PATCH", path: SESSION_PATH_RE }
          handle_session_event(request, $~[:session_id])
        in _ if response = handle_provider_route(request)
          response
        in method: "GET" | "HEAD" | "POST" if is_new_session_request?(request)
          handle_session_start(request)
        else
          handle_404(request)
        end
      rescue Session::Errors::SessionNotFoundError
        error_response(403, "SESSION_NOT_FOUND", **origin_header(request))
      rescue Session::Errors::SessionIdMismatchError
        error_response(403, "SESSION_ID_MISMATCH", **origin_header(request))
      rescue Session::Errors::InvalidTokenError
        error_response(403, "INVALID_TOKEN", **origin_header(request))
      rescue Cookies::TokenCookieNotSetError => e
        error_response(403, "TOKEN_COOKIE_NOT_SET", **origin_header(request))
      rescue Errno::ENOENT => e
        text_response(
          404,
          "Resource not found: #{request.path}",
          **origin_header(request)
        )
      rescue => e
        Console.logger.error(self, e)
        error_response(403, "INTERNAL_SERVER_ERROR", **origin_header(request))
      end

      def stop
        @stopping = true
        @sessions.stop
        @sessions.transfer_all
      ensure
        @body_barrier.wait
      end

      private

      def is_new_session_request?(request)
        !request.path.start_with?("/.mayu") &&
          request.headers["accept"]&.include?("text/html")
      end

      def handle_provider_route(request)
        provider = @environment.module_provider
        return unless provider

        match = Klenod::Router.new(provider).match(request.path)
        handler = match&.handler
        return unless handler
        return if html_page_request?(request, match)

        method = request.method.to_s.upcase
        unless handler.public_method_defined?(method)
          return(
            response(
              405,
              "Method Not Allowed",
              **{
                "allow" => handler_methods(handler).join(", "),
                "vary" => "Accept"
              }
            )
          )
        end

        status, headers, body =
          handler.new.public_send(
            method,
            Route::Request.from_async(request, params: match.params)
          )
        response(status, body, **headers.merge("vary" => "Accept"))
      end

      def html_page_request?(request, match)
        return false unless match.page
        unless %w[GET HEAD POST].include?(request.method.to_s.upcase)
          return false
        end

        request.headers["accept"].to_s.include?("text/html")
      end

      def handler_methods(handler)
        handler
          .public_instance_methods(false)
          .map { _1.to_s.upcase }
          .select do |name|
            %w[GET HEAD POST PUT PATCH DELETE OPTIONS].include?(name)
          end
          .sort
      end

      # Mayu

      def handle_options(request)
        response(204, **ALLOW_HEADERS, **origin_header(request))
      end

      def handle_init_js(request)
        Protocol::HTTP::Response[
          200,
          {
            "content-type": "application/javascript",
            "cache-control": "no-store",
            **origin_header(request)
          },
          @environment.init_js_body
        ]
      end

      def handle_script(request)
        path =
          Pathname
            .new(request.path)
            .relative_path_from("/.mayu/runtime")
            .then { File.absolute_path(_1, "/") }

        file = @client_files.get(path)

        unless file
          return(
            response(
              404,
              "Resource not found: #{request.path}",
              "content-type": "text/plain; charset=utf-8",
              **origin_header(request)
            )
          )
        end

        response(
          200,
          file.encoded_content.content,
          "cache-control": ASSET_CACHE_CONTROL,
          **file.headers,
          **origin_header(request)
        )
      end

      def handle_asset(request)
        provider = @environment.module_provider
        return text_response(404, "file not found") unless provider

        klenod_asset_app(provider).response_for(
          request,
          headers: {
            **origin_header(request)
          }
        ) || text_response(404, "file not found")
      end

      def klenod_asset_app(provider)
        return @klenod_asset_app if @klenod_asset_provider.equal?(provider)

        @klenod_asset_provider = provider
        @klenod_asset_app = Klenod::AssetApp.new(provider)
      end

      def handle_favicon(request)
        send_file(
          File.read(File.join(@environment.app_dir, "favicon.png")),
          "image/png",
          { **origin_header(request), **ASSET_CACHE_CONTROL_HEADER }
        )
      end

      def handle_404(request)
        text_response(404, "file not found")
      end

      # Session

      def handle_session_start(request)
        session =
          Session.new(
            request_info: Session::RequestInfo.from_request(request),
            environment: @environment
          )

        if request.version == "HTTP/2"
          @sessions.store(session)
          @environment.metrics.session_init_count.increment
        end

        body = session.render

        response(
          200,
          body,
          "content-type": "text/html; charset=utf-8",
          "x-mayu-session-id": session.id,
          **@cookies.set_token_cookie_header(session),
          link: link_header(session)
        )
      end

      def link_header(session)
        [
          # "<%s>; rel=preload; as=script; crossorigin=same-origin; fetchpriority=high" %
          #   escape_link_header_path(session.init_js_path),
          "<%s>; rel=modulepreload; as=script; crossorigin=same-origin; fetchpriority=high" %
            escape_link_header_path(@environment.runtime_js_path),
          *session.styles.map do
            "<%s>; rel=preload; as=style" %
              escape_link_header_path(asset_url(it))
          end
        ].join(", ")
      end

      def asset_url(path)
        return path if path.start_with?("/", "http://", "https://")

        "/.mayu/assets/#{path}"
      end

      def escape_link_header_path(path)
        path.gsub("<", "%3C").gsub(">", "%3E")
      end

      def handle_session_transfer(request, session_id)
        session =
          Session::TransferState
            .decrypt(@environment.marshaller, request.read.to_s)
            .authenticate!(
              session_id:,
              session_token: @cookies.get_token_cookie_value(request)
            )
            .resume(@environment)

        @sessions.store(session)

        Console.logger.info(
          self,
          "\e[32mResuming transferred session stream #{session.id}\e[0m"
        )

        run_session_stream(request, session)
      rescue Mayu::EncryptedMarshal::ExpiredError
        error_response(403, "SESSION_EXPIRED")
      rescue Mayu::EncryptedMarshal::DecryptError => e
        Console.logger.error(self, e)
        error_response(403, "SESSION_CIPHER_ERROR")
      end

      def handle_session_resume(request, session_id)
        session =
          @sessions.authenticate!(
            session_id,
            @cookies.get_token_cookie_value(request)
          )

        Console.logger.info(
          self,
          "\e[32mResuming session stream #{session.id}\e[0m"
        )

        run_session_stream(request, session)
      end

      def run_session_stream(request, session)
        headers = {
          "content-type": EventStream::CONTENT_TYPE,
          "content-encoding": EventStream::CONTENT_ENCODING,
          **@cookies.set_token_cookie_header(session),
          **origin_header(request)
        }

        if session.running?
          Console.logger.error(self, "already running")

          return(
            error_response(
              409,
              "SESSION_ALREADY_RUNNING",
              **origin_header(request)
            )
          )
        end

        body = EventStream::Writer.new

        body.write(Runtime::Patches::Initialize[session.dom_id_tree.serialize])

        @body_barrier.async do |task|
          session.start

          task.async do
            body.wait
            task.stop
          end

          loop do
            patch = session.dequeue_patch

            break if body.closed?

            next unless patch

            body.write(patch)

            break if patch in Runtime::Patches::Transfer
          end
        rescue => e
          Console.logger.error(self, e)
        ensure
          session.stop
          body.close
        end

        Protocol::HTTP::Response[200, headers, body]
      end

      def handle_session_event(request, session_id)
        session =
          @sessions.authenticate!(
            session_id,
            @cookies.get_token_cookie_value(request)
          )

        Async do
          session.wait
        ensure
          request.body.close
        end

        EventStream.each_incoming_message(request) do |message|
          Session::Events
            .from_message(message)
            .each { |event| session.enqueue_event(event) }
        end

        json_response(
          204,
          "ok",
          **@cookies.set_token_cookie_header(session),
          **origin_header(request)
        )
      end

      # Helpers

      def text_response(status, *bodies, **headers)
        response(
          status,
          *bodies,
          "content-type": "text/plain; charset-utf-8",
          **headers
        )
      end

      def error_response(status, error, **headers)
        json_response(status, { error: }, **headers)
      end

      def json_response(status, json, **headers)
        response(
          status,
          JSON.generate(json),
          "content-type": "application/json",
          **headers
        )
      end

      def response(status, *bodies, **headers)
        Protocol::HTTP::Response[status, headers, bodies]
      end

      def origin_header(request)
        if request.headers["origin"] in [origin]
          { "access-control-allow-origin": origin }
        else
          {}
        end
      end

      def send_file(content, content_type, headers = {})
        Protocol::HTTP::Response[
          200,
          { "content-type": content_type, **headers },
          [content]
        ]
      end
    end
  end
end
