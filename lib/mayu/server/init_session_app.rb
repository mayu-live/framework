# typed: false

require_relative "session"

module Mayu
  module Server
    class InitSessionApp
      def initialize(environment)
        @environment = environment
      end

      def call(env)
        request = Rack::Request.new(env)

        if request.path_info == "/favicon.ico"
          return [
            404,
            { "content-type" => "text/plain" },
            ["There is no favicon"]
          ]
        end

        unless env["REQUEST_METHOD"].to_s == "GET"
          return 405, {}, ["Only GET requests are supported."]
        end

        unless env["HTTP_ACCEPT"].to_s.split(",").include?("text/html")
          return 406, {}, ["Not acceptable, try requesting HTML instead"]
        end

        session =
          Session.init(
            environment: @environment,
            request_path: request.path_info
          )

        response =
          Rack::Response.new(
            session.initial_render,
            200,
            {
              "content-type" => "text/html; charset=utf-8",
              "cache-control" => "no-store"
            }
          )

        response.set_cookie(
          session.cookie_name,
          {
            path: "/__mayu/",
            secure: true,
            http_only: true,
            same_site: :strict,
            value: session.key
          }
        )

        response.finish
      end
    end
  end
end
