# typed: false

require_relative "session"

module Mayu
  module Server
    class CallbackHandlerApp
      MOUNT_PATH = "/__mayu/handler"
      DEFAULT_HEADERS = { "content-type" => "text/plain" }

      def call(env)
        request = Rack::Request.new(env)
        session_id, handler_id = request.path_info.to_s.split("/", 3).last(2)
        cookie_name = Session.cookie_name(session_id)
        session_key =
          request
            .cookies
            .fetch(cookie_name) do
              return 401, DEFAULT_HEADERS, ["Session cookie not set"]
            end

        payload = JSON.parse(request.body.read)

        case Session.handle_callback(
          session_id,
          session_key,
          handler_id,
          payload
        )
        when :session_not_found
          [404, DEFAULT_HEADERS, ["Session not found"]]
        else
          [200, DEFAULT_HEADERS, ["ok"]]
        end
      end
    end
  end
end
