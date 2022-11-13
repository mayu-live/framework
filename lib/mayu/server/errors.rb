# typed: strict
# frozen_string_literal: true

module Mayu
  module Server
    module Errors
      extend T::Sig

      class ServerError < StandardError
      end

      class FileNotFound < ServerError
      end
      class CookieNotSet < ServerError
      end
      class InvalidToken < ServerError
      end
      class InvalidMethod < ServerError
      end
      class UnauthorizedSessionCookie < ServerError
      end
      class SessionAlreadyResumed < ServerError
      end
      class SessionNotFound < ServerError
      end
      class ServerIsShuttingDown < ServerError
      end
      class InvalidSecFetchHeader < ServerError
      end

      sig do
        params(block: T.proc.returns(Protocol::HTTP::Response)).returns(
          Protocol::HTTP::Response
        )
      end
      def self.handle_exceptions(&block)
        respond_to_exceptions { log_exceptions { yield } }
      end

      sig do
        params(block: T.proc.returns(Protocol::HTTP::Response)).returns(
          Protocol::HTTP::Response
        )
      end
      def self.log_exceptions(&block)
        yield
      rescue => e
        Console.logger.error(self, e)
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        raise
      end

      sig do
        params(block: T.proc.returns(Protocol::HTTP::Response)).returns(
          Protocol::HTTP::Response
        )
      end
      def self.respond_to_exceptions(&block)
        yield
      rescue Errno::ENOENT => e
        text_response(404, "file not found")
      rescue FileNotFound => e
        text_response(404, e.message.to_s)
      rescue CookieNotSet => e
        text_response(403, "session cookie not set")
      rescue SessionNotFound => e
        text_response(404, "session not found")
      rescue Mayu::MessageCipher::DecryptError => e
        text_response(403, "decrypt error")
      rescue Mayu::MessageCipher::ExpiredError => e
        text_response(403, "session expired")
      rescue InvalidToken => e
        text_response(403, "invalid token")
      rescue SessionAlreadyResumed => e
        text_response(409, "already resumed")
      rescue Session::AlreadyRunningError => e
        text_response(409, "already running")
      rescue ServerIsShuttingDown => e
        # https://fly.io/docs/reference/fly-replay/#fly-replay
        text_response(
          405,
          "invalid method",
          { "fly-replay" => "elsewhere=true" }
        )
      rescue InvalidMethod => e
        text_response(405, "invalid method")
      rescue UnauthorizedSessionCookie => e
        text_response(403, "session cookie is invalid")
      rescue InvalidSecFetchHeader => e
        text_response(415, e.message)
      rescue StandardError
        text_response(500, "error")
      end

      sig do
        params(
          code: Integer,
          text: String,
          headers: T::Hash[String, String]
        ).returns(Protocol::HTTP::Response)
      end
      def self.text_response(code, text, headers = {})
        Protocol::HTTP::Response[
          code,
          { "content-type" => "text/plain", **headers },
          [text]
        ]
      end
    end
  end
end
