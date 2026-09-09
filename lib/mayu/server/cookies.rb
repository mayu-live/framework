# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  class Server
    class Cookies
      class TokenCookieNotSetError < StandardError
      end

      def initialize(timeout_seconds: 60)
        @timeout_seconds = 60
      end

      def get_token_cookie_value(request)
        Array(request.headers["cookie"]).each do |str|
          if (match = str.match(/^mayu-token=(\w+)/))
            return match[1].to_s.tap { Session::Token.validate!(it) }
          end
        end

        raise TokenCookieNotSetError
      end

      def set_token_cookie_header(session)
        {"set-cookie": set_token_cookie_value(session)}
      end

      def set_token_cookie_value(session)
        expires = Time.now.utc + @timeout_seconds

        [
          "mayu-token=#{session.token}",
          "path=/.mayu/session/#{session.id}",
          "expires=#{expires.httpdate}",
          "secure",
          "HttpOnly",
          "SameSite=Strict"
        ].join("; ")
      end
    end
  end
end
