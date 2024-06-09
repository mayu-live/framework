# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "protocol/http/body/file"
require_relative "request_refinements"
require_relative "cookies"
require_relative "session_store"
require_relative "event_stream"
require_relative "static_files"

require_relative "../environment"
require_relative "../session"
require_relative "../modules/system"

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

      def initialize(config)
        @stopping = false
        @environment = Environment.from_config(config)
        @sessions = SessionStore.new
        @client_files = StaticFiles.new(@environment.client_path)
        @sessions.start_cleanup_task
      end

      def call(request)
        return text_response(503, "Server is stopping") if @stopping

        # puts "\e[3;33m #{request.method} #{request.path} \e[0m"

        case request
        in path: "/favicon.ico"
          handle_favicon(request)
        in { path: "/.mayu", method: "OPTIONS" }
          handle_options(request)
        in path: %r{\A\/.mayu\/runtime\/.+\.js(\.map)?}
          handle_script(request)
        in { path: %r{\A/\.mayu/assets/(.+)\z}, method: "GET" }
          handle_asset(request)
        in {
             method: "GET",
             path: %r{\/.mayu\/session\/(?<session_id>[[:alnum:]]+)}
           }
          handle_session_resume(request, $~[:session_id])
        in {
             method: "POST",
             path: %r{\/.mayu\/session\/(?<session_id>[[:alnum:]]+)}
           }
          handle_session_transfer(request, $~[:session_id])
        in {
             path: %r{\/.mayu\/session\/(?<session_id>[[:alnum:]]+)},
             method: "PATCH"
           }
          handle_session_event(request, $~[:session_id])
        in method: "GET"
          handle_session_start(request)
        else
          handle_404(request)
        end
      rescue SessionStore::SessionNotFoundError
        error_response(403, "Session not found", **origin_header(request))
      rescue SessionStore::InvalidTokenError
        error_response(403, "Invalid token", **origin_header(request))
      rescue Cookies::TokenCookieNotSetError
        error_response(403, "Token cookie not set", **origin_header(request))
      rescue Errno::ENOENT => e
        text_response(
          404,
          "Resource not found: #{request.path}",
          **origin_header(request)
        )
      rescue => e
        Console.logger.error(self, e)
        error_response(403, "Internal server error", **origin_header(request))
      end

      def stop
        @stopping = true
        Console.logger.info(self, "\e[1;33mTRANSFERRING ALL SESSIONS\e[0m")
        @sessions.transfer_all
        Console.logger.info(self, "\e[32mTRANSFERRED ALL SESSIONS\e[0m")
      end

      private

      # Mayu

      def handle_options(request)
        response(204, **ALLOW_HEADERS, **origin_header(request))
      end

      def handle_script(request)
        path =
          Pathname.new(request.path).relative_path_from("/.mayu/runtime").to_s

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
          **file.headers,
          **origin_header(request)
        )
      end

      def handle_asset(request)
        asset =
          request
            .path
            .then { _1.delete_prefix("/.mayu/assets/") }
            .then { CGI.unescape_uri_component(_1) }
            .tap { puts "Retreiving asset #{_1.inspect}" }
            .then { Modules::System.current.wait_for_asset(_1) }

        return text_response(404, "file not found") unless asset

        puts "Got asset #{asset.filename}"

        case asset.encoded_content
        in Modules::Assets::FileContent
          puts "Reading #{File.join(".assets", asset.filename)}"

          Protocol::HTTP::Response[
            200,
            { **asset.headers, **origin_header(request) },
            Protocol::HTTP::Body::File.open(
              File.join(".assets", asset.filename)
            )
          ]
        in Modules::Assets::EncodedContent
          response(
            200,
            asset.encoded_content.content,
            **asset.headers,
            **origin_header(request)
          )
        end
      end

      def handle_favicon(request)
        send_file(
          File.read(File.join(@environment.app_dir, "favicon.png")),
          "image/png",
          origin_header(request)
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

        @sessions.store(session)

        body = session.render.to_html

        response(
          200,
          body,
          "content-type": "text/html; charset=utf-8",
          "x-mayu-session-id": session.id,
          **Cookies.set_token_cookie_header(session),
          link: link_header(session)
        )
      end

      def link_header(session)
        [
          "<#{@environment.runtime_js_for_session_id(session.id)}>; rel=preload; as=script; crossorigin=same-origin; fetchpriority=high",
          *session.styles.map do
            "</.mayu/assets/#{CGI.escape_uri_component(_1)}>; rel=preload; as=style"
          end
        ].join(", ")
      end

      def handle_session_transfer(request, session_id)
        encrypted_session = request.read.to_s
        session = Session.resume_transferred(@environment, encrypted_session)

        unless session.id == session_id
          return error_response(403, "invalid session id")
        end

        # TODO: Validate token

        @sessions.store(session)

        run_session_stream(request, session)
      rescue Mayu::EncryptedMarshal::ExpiredError
        error_response(403, "expired")
      rescue Mayu::EncryptedMarshal::DecryptError => e
        Console.logger.error(self, e)
        error_response(403, "cipher error")
      end

      def handle_session_resume(request, session_id)
        session =
          @sessions.authenticate(
            session_id,
            Cookies.get_token_cookie_value(request)
          )

        return session_not_found_response unless session

        run_session_stream(request, session)
      end

      def run_session_stream(request, session)
        headers = {
          "content-type": EventStream::CONTENT_TYPE,
          "content-encoding": EventStream::CONTENT_ENCODING,
          "set-cookie": Cookies.set_token_cookie_value(session),
          **origin_header(request)
        }

        body = EventStream::Writer.new

        body.write(
          Runtime::Patches::Initialize[session.render.id_node.serialize]
        )

        Async do |task|
          session.run do |patch|
            body.write(patch)

            if patch in Runtime::Patches::Transfer
              body.close
              task.stop
            end
          end

          Console.logger.info(self, "\e[31mStopped session #{session.id}\e[0m")

          body.wait
        ensure
          task.stop
        end

        Protocol::HTTP::Response[200, headers, body]
      end

      def session_not_found_response(request)
        response(
          404,
          "Session not found/invalid token",
          **origin_header(request),
          "content-type": "text/plain"
        )
      end

      def handle_session_event(request, session_id)
        session =
          @sessions.authenticate(
            session_id,
            Cookies.get_token_cookie_value(request)
          )

        return session_not_found_response unless session

        Async do
          session.wait
        ensure
          request.body.close
        end

        EventStream.each_incoming_message(request) do |message|
          case message
          in { type: "callback", payload: { id:, event: }, ping: }
            session.handle_ping(ping)
            session.handle_callback(id, event)
          in {
               type: "navigate",
               payload: { href:, pushState: push_state },
               ping:
             }
            session.handle_ping(ping)
            session.handle_navigate(href, push_state:)
          in { type: "ping", ping: }
            session.handle_ping(ping)
          end
        end

        json_response(
          204,
          "ok",
          "set-cookie": Cookies.set_token_cookie_value(session),
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
        { "access-control-allow-origin": request.headers["origin"] }
      end

      def send_file(content, content_type, headers = {})
        Protocol::HTTP::Response[
          200,
          {
            "content-type": content_type,
            "content-length": content.bytesize,
            **headers
          },
          [content]
        ]
      end
    end
  end
end
