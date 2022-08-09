# typed: false

require_relative "session"

module Mayu
  module Server
    class CallbackHandlerApp
      MOUNT_PATH = "/__mayu/handler"

      def call(env)
        request = Rack::Request.new(env)
        session_id, handler_id = request.path_info.to_s.split("/", 3).last(2)
        cookie_name = Session.cookie_name(session_id)
        session_key =
          request
            .cookies
            .fetch(cookie_name) { return 401, {}, ["Session cookie not set"] }

        payload = JSON.parse(request.body.read)

        case Session.handle_callback(
          session_id,
          session_key,
          handler_id,
          payload
        )
        when :session_not_found
          [404, {}, ["Session not found"]]
        else
          [200, {}, ["ok"]]
        end
      end
    end
  end
end
