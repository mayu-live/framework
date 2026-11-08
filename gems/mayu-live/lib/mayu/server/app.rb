# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "request_refinements"
require_relative "cookies"
require_relative "event_stream"
require_relative "static_files"

require_relative "../environment"
require_relative "../request_origin"
require_relative "../runtime/engine"
require_relative "../session"
require_relative "../session/store"
require_relative "../klenod"

module Mayu
  class Server
    class App
      using RequestRefinements

      ASSET_CACHE_CONTROL = [
        "public",
        "max-age=#{7 * 24 * 60 * 60}",
        "immutable"
      ].join(", ").freeze

      ROBOTS_TXT_ENTRY = "robots.txt"
      ROBOTS_TXT_CACHE_CONTROL = "public, max-age=#{60 * 60}"

      FAVICON_ENTRY = "virtual:mayu/favicon"
      FAVICON_CACHE_CONTROL = "public, max-age=#{60 * 60}"

      def initialize(environment)
        @environment = environment
        @stopping = false
        @sessions = Session::Store.new(metrics: @environment.metrics)
        @body_barrier = Async::Barrier.new(parent: Async::Task.current)
        @streams = {}
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
        @environment.wrap_request(request) { dispatch(it) }
      end

      def dispatch(request)
        return text_response(503, "Server is stopping") if @stopping

        if protected_request?(request) && !request_origin_allowed?(request)
          return error_response(403, "REQUEST_ORIGIN_REJECTED", **{"cache-control" => "no-store"})
        end

        case request
        in {path: "/favicon.ico", method: "GET" | "HEAD"}
          handle_favicon(request)
        in {path: "/robots.txt", method: "GET" | "HEAD"}
          handle_robots_txt(request)
        in {path: "/.mayu", method: "OPTIONS"}
          handle_options(request)
        in path: %r{\A/.mayu/runtime/.+\.js(\.map)?}
          handle_script(request)
        in {path: %r{\A/\.mayu/assets/(.+)\z}, method: "GET"}
          handle_asset(request)
        in {method: "GET", path: SESSION_PATH_RE}
          handle_session_resume(request, $~[:session_id])
        in {method: "POST", path: SESSION_PATH_RE}
          handle_session_transfer(request, $~[:session_id])
        in {method: "PATCH", path: SESSION_PATH_RE}
          handle_session_event(request, $~[:session_id])
        in _ if response = handle_provider_route(request)
          response
        in method: "GET" | "HEAD" | "POST" if page_request?(request)
          handle_session_start(request)
        else
          handle_404(request)
        end
      rescue RequestOrigin::Rejected
        error_response(403, "REQUEST_ORIGIN_REJECTED", **{"cache-control" => "no-store"})
      rescue Session::Rejected => rejection
        json_response(403, {code: "APPLICATION_SESSION_REJECTED", location: rejection.location})
      rescue Session::Errors::SessionNotFoundError
        error_response(403, "SESSION_NOT_FOUND")
      rescue Session::Errors::SessionIdMismatchError
        error_response(403, "SESSION_ID_MISMATCH")
      rescue Session::Errors::InvalidTokenError
        error_response(403, "INVALID_TOKEN")
      rescue Cookies::TokenCookieNotSetError
        error_response(403, "TOKEN_COOKIE_NOT_SET")
      rescue EventStream::MessageTooLargeError
        error_response(413, "EVENT_MESSAGE_TOO_LARGE")
      rescue EventStream::InvalidMessageError, Session::Events::InvalidEventError => e
        Console.logger.warn(self, e)
        error_response(400, "INVALID_EVENT_MESSAGE")
      rescue Session::Events::EventRejectedError => e
        Console.logger.debug(self, e)
        error_response(
          409,
          "SESSION_NOT_ACCEPTING_EVENTS"
        )
      rescue Klenod::Router::MalformedPathError
        # Routing runs before a session starts, so a malformed path never
        # reaches the session or the app's error and not-found pages, which
        # would have to route the same path.
        text_response(400, "Bad Request")
      rescue Errno::ENOENT
        text_response(
          404,
          "Resource not found: #{request.path}"
        )
      rescue Runtime::VNodes::VComponent::UnhandledRenderError => failure
        # The session reported it, and its error page failed as well.
        render_error_response(failure, request)
      rescue => e
        provider = @environment.module_provider
        provider.rewrite_exception(e) if provider.respond_to?(:rewrite_exception)
        # A build error already says where it happened, so the development
        # provider formats it without the backtrace through the build graph.
        report = provider.build_error_report(e) if provider.respond_to?(:build_error_report)
        Console.logger.error(self, report || e)

        if browser_navigation?(request) && @environment.config.server.render_exceptions?
          text_response(500, report || exception_text(e))
        else
          error_response(500, "INTERNAL_SERVER_ERROR")
        end
      end

      def render_error_response(failure, request)
        error = failure.error
        body =
          if @environment.config.server.render_exceptions?
            exception_text(error)
          else
            "Internal Server Error"
          end

        text_response(500, body)
      end

      def exception_text(error)
        message = Runtime::Commands.utf8(error.message)
        ["#{error.class}: #{message}", "", *error.backtrace].join("\n")
      end

      # Called by the development build after it applied a source change.
      def notify_hmr_update(update)
        @sessions.each { |session| session.notify_hmr_update(update) }
      end

      def begin_shutdown
        @stopping = true
        @sessions.stop
      end

      def stop
        begin_shutdown
        @sessions.transfer_all
        @body_barrier.wait
      end

      def invalidate_session(id, location: nil)
        @sessions.invalidate(id, location:)
      end

      def stream_count
        @streams.size
      end

      def abort
        begin_shutdown
        @streams.values.each(&:close)
        @body_barrier.stop
      ensure
        @sessions.abort
      end

      private

      def protected_request?(request)
        return true if SESSION_PATH_RE.match?(request.path.split("?", 2).first)
        return false if %w[GET HEAD OPTIONS].include?(request.method)
        return true if request.path.start_with?("/.mayu")

        provider = @environment.module_provider
        match = provider && Klenod::Router.new(provider).match(request.path)
        handler = match&.handler
        !(handler && !html_page_request?(request, match) && handler.csrf_exempt?(request.method))
      end

      def request_origin_allowed?(request)
        RequestOrigin.allowed?(request, expected_origin: request_origin(request))
      end

      def request_origin(request)
        config = @environment.config.server
        RequestOrigin.resolve(request, public_origin: config.public_origin, trusted_proxies: config.trusted_proxies)
      rescue ArgumentError
        raise RequestOrigin::Rejected
      end

      def check_session_origin!(request, origin)
        raise RequestOrigin::Rejected unless request_origin(request) == origin
      end

      # Pages are served to any client. Paths without a page only render the
      # app's not-found page for browser navigations, so stray asset requests
      # get a plain 404 instead.
      def page_request?(request)
        return false if request.path.start_with?("/.mayu")

        provider = @environment.module_provider
        return true unless provider
        return true if Klenod::Router.new(provider).match(request.path)&.page

        browser_navigation?(request)
      end

      # Only browser navigations keep a live session, so scripted clients like
      # curl get the HTML without filling the session store.
      def browser_navigation?(request)
        request.headers["accept"].to_s.include?("text/html")
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
          return (
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
        # Rack-style header arrays (especially Set-Cookie) represent separate
        # fields. Protocol headers require each field's value to be a string.
        fields = headers.merge("vary" => "Accept").flat_map do |name, value|
          Array(value).map { |field| [name.to_s, field] }
        end
        Protocol::HTTP::Response[status, fields, body]
      end

      def html_page_request?(request, match)
        return false unless match.page
        unless %w[GET HEAD POST].include?(request.method.to_s.upcase)
          return false
        end

        browser_navigation?(request)
      end

      def handler_methods(handler)
        handler
          .public_instance_methods(false)
          .map { it.to_s.upcase }
          .select do |name|
            %w[GET HEAD POST PUT PATCH DELETE OPTIONS].include?(name)
          end
          .sort
      end

      # Mayu

      def handle_options(request)
        response(204)
      end

      def handle_script(request)
        path =
          Pathname
            .new(request.path)
            .relative_path_from("/.mayu/runtime")
            .then { File.absolute_path(it, "/") }

        file = @client_files.get(path)

        unless file
          return (
            response(
              404,
              "Resource not found: #{request.path}",
              "content-type": "text/plain; charset=utf-8"
            )
          )
        end

        response(
          200,
          file.encoded_content.content,
          "cache-control": script_cache_control(request.path),
          **file.headers
        )
      end

      # The initializer reads its session id from the fragment of its URL. A
      # browser reuses a cached module together with the URL it first loaded
      # it from, so after a reload the page would resume the previous session.
      # The initializer is tiny, so it is never cached.
      def script_cache_control(path)
        if path == @environment.runtime_init_js_path
          "no-store"
        else
          ASSET_CACHE_CONTROL
        end
      end

      def handle_asset(request)
        provider = @environment.module_provider
        return text_response(404, "file not found") unless provider

        klenod_asset_app(provider).response_for(request) || text_response(404, "file not found")
      end

      def klenod_asset_app(provider)
        return @klenod_asset_app if @klenod_asset_provider.equal?(provider)

        @klenod_asset_provider = provider
        @klenod_asset_app = Klenod::AssetApp.new(provider)
      end

      def handle_favicon(request)
        provider = @environment.module_provider
        return handle_404(request) unless provider

        # Read the export on every request so dev serves hot-reloaded edits.
        favicon = provider.exports(provider.entry(FAVICON_ENTRY))::Default
        return handle_404(request) unless favicon

        etag = %("#{favicon.fetch(:etag)}")
        headers = {
          "cache-control": FAVICON_CACHE_CONTROL,
          etag:
        }

        if request.headers["if-none-match"]&.weak_match?(etag)
          return response(304, **headers)
        end

        send_file(favicon.fetch(:body), "image/x-icon", headers)
      rescue *missing_entry_errors
        handle_404(request)
      end

      def handle_robots_txt(request)
        provider = @environment.module_provider
        return handle_404(request) unless provider

        # Read the export on every request so dev serves hot-reloaded edits.
        robots_txt = provider.exports(provider.entry(ROBOTS_TXT_ENTRY))::Default
        send_file(
          robots_txt,
          "text/plain; charset=utf-8",
          {"cache-control": ROBOTS_TXT_CACHE_CONTROL}
        )
      rescue *missing_entry_errors
        handle_404(request)
      end

      # A runtime bundle raises KeyError for an entry it doesn't contain. The
      # development provider raises Klenod::Build::ResolveError, which is only
      # defined when mayu-build is loaded.
      def missing_entry_errors
        [
          KeyError,
          (::Klenod::Build::ResolveError if defined?(::Klenod::Build::ResolveError))
        ].compact
      end

      def handle_404(request)
        text_response(404, "file not found")
      end

      # Session

      def handle_session_start(request)
        origin = request_origin(request)
        preparation = @environment.prepare_session_for(request)
        return preparation if preparation.is_a?(Protocol::HTTP::Response)
        unless preparation.is_a?(Session::Preparation)
          raise TypeError, "prepare_session must return a context hash, Session::Preparation, or a response"
        end
        session =
          begin
            Session.new(
              request_info: Session::RequestInfo.from_request(request, origin:),
              environment: @environment,
              context: preparation.context
            ) { |info| @environment.authorize_session!(info, request:, phase: :start) }
          rescue Session::Rejected => rejection
            return rejected_session_start_response(request, preparation, rejection)
          end

        if @stopping
          session.stop
          return text_response(503, "Server is stopping")
        end

        if request.version == "HTTP/2" && browser_navigation?(request)
          @sessions.store(session)
          @environment.metrics.session_starts_total.increment
        end

        body = session.render

        result = response(
          session.route_status || 200,
          body,
          "content-type": "text/html; charset=utf-8",
          vary: "Accept",
          "x-mayu-session-id": session.id,
          **@cookies.set_token_cookie_header(session),
          link: link_header(session)
        )
        preparation.headers.each { |name, value| result.headers.add(name.to_s, value) }
        result
      end

      def rejected_session_start_response(request, preparation, rejection)
        headers = {"cache-control" => "no-store", "vary" => "Accept"}
        result = if browser_navigation?(request)
          if rejection.location
            response(303, **headers, location: rejection.location)
          else
            text_response(403, "Forbidden", **headers)
          end
        else
          json_response(403, {code: "APPLICATION_SESSION_REJECTED", location: rejection.location}, **headers)
        end
        preparation.headers.each { |name, value| result.headers.add(name.to_s, value) }
        result
      end

      def link_header(session)
        [
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
        state = request.read.to_s
        return text_response(503, "Server is stopping") if @stopping

        begin
          transfer =
            Session::TransferState
              .decrypt(@environment.marshaller, state)
              .authenticate!(
                session_id:,
                session_token: @cookies.get_token_cookie_value(request)
              )
        rescue TypeError, ArgumentError, NoMatchingPatternError
          return error_response(422, "SESSION_RESTORE_FAILED")
        end

        # Components that can not be restored start over on their own, so
        # this only fails when the session as a whole can not be loaded, such
        # as after a change to the transfer format. The client then starts a
        # new session right away instead of retrying the same state.
        begin
          transfer.validate_metadata!
        rescue => error
          Console.logger.error(self, error)
          return error_response(422, "SESSION_RESTORE_FAILED")
        end
        @sessions.check_valid!(session_id)
        check_session_origin!(request, transfer.info.origin)
        @environment.authorize_session!(transfer.info, request:, phase: :transfer)
        @sessions.check_valid!(session_id)
        begin
          session = transfer.resume(@environment)
        rescue => error
          Console.logger.error(self, "Could not restore transferred session #{session_id}", error)
          return error_response(422, "SESSION_RESTORE_FAILED")
        end

        if @stopping
          session.stop
          return text_response(503, "Server is stopping")
        end

        @sessions.check_valid!(session_id)
        @sessions.store(session)

        Console.logger.info(
          self,
          event: Mayu::Session::Event.new(:resuming_transferred, session_id: session.id)
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

        authorize_transport!(session, request, :resume)

        Console.logger.info(
          self,
          event: Mayu::Session::Event.new(:resuming, session_id: session.id)
        )

        run_session_stream(request, session)
      end

      def authorize_transport!(session, request, phase)
        check_session_origin!(request, session.origin)
        session.check_valid!
        @environment.authorize_session!(session.info, request:, phase:)
        session.check_valid!
      rescue Session::Rejected => rejection
        session.invalidate!(location: rejection.location)
        raise
      end

      def run_session_stream(request, session)
        headers = {
          "content-type": EventStream::CONTENT_TYPE,
          "content-encoding": EventStream::CONTENT_ENCODING,
          **@cookies.set_token_cookie_header(session)
        }

        if session.running?
          Console.logger.error(self, "already running")

          return (
            error_response(
              409,
              "SESSION_ALREADY_RUNNING"
            )
          )
        end

        body = EventStream::Writer.new(metrics: @environment&.metrics)
        @streams[session.id] = body

        body.write_batch(
          Runtime::Batch[
            [
              Runtime::Commands::Initialize[session.dom_id_tree],
              *session.listener_commands,
              *session.startup_commands
            ]
          ]
        )

        @body_barrier.async do |task|
          session.start

          batch_task = task.async do
            loop do
              batch = session.dequeue_batch

              break if body.closed?

              next unless batch

              body.write_batch(batch) unless batch.empty?
              batch.complete

              break if batch.terminal?
            end
          end

          close_task = task.async do
            body.wait
            batch_task.stop
          end
          session_task = task.async do
            session.wait
            batch_task.stop unless session.transferring?
          end

          begin
            batch_task.wait
          ensure
            close_task.stop
            session_task.stop
            session.stop
            body.close_write
          end

          flushed = body.wait_finished
          Console.logger.info(
            self,
            event: Mayu::Session::Event.new(:stream_finished, session_id: session.id, flushed:)
          )
        rescue => e
          Console.logger.error(self, e)
          body.close(e)
        ensure
          session.stop
          @streams.delete(session.id)
        end

        Protocol::HTTP::Response[200, headers, body]
      end

      def handle_session_event(request, session_id)
        session =
          @sessions.authenticate!(
            session_id,
            @cookies.get_token_cookie_value(request)
          )

        authorize_transport!(session, request, :events)

        Async do
          session.wait
        ensure
          request.body.close
        end

        EventStream.each_incoming_message(request) do |message|
          break if @stopping
          session.receive_message(message)
        end

        if @stopping
          return error_response(
            503,
            "SERVER_STOPPING"
          )
        end

        # A 204 has no body. A body would make the server send content-length,
        # which HTTP/2 clients reject on a 204.
        Protocol::HTTP::Response[
          204,
          {
            **@cookies.set_token_cookie_header(session)
          },
          nil
        ]
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

      def error_response(status, code, message: code, **headers)
        json_response(status, {code:, message:, error: code}, **headers)
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
        Protocol::HTTP::Response[status, headers.transform_keys(&:to_s), bodies]
      end

      def send_file(content, content_type, headers = {})
        Protocol::HTTP::Response[
          200,
          {"content-type" => content_type, **headers.transform_keys(&:to_s)},
          [content]
        ]
      end
    end
  end
end
