# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  class Server
    module Cookies
      class TokenCookieNotSetError < StandardError
      end

      def self.get_token_cookie_value(request)
        Array(request.headers["cookie"]).each do |str|
          if match = str.match(/^mayu-token=(\w+)/)
            return match[1].to_s.tap { Session::Token.validate!(_1) }
          end
        end

        raise TokenCookieNotSetError
      end

      def self.set_token_cookie_header(session, ttl_seconds: 60)
        { "set-cookie": set_token_cookie_value(session, ttl_seconds:) }
      end

      def self.set_token_cookie_value(session, ttl_seconds: 60)
        expires = Time.now.utc + ttl_seconds

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
