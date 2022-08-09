# typed: false

require_relative "session"

module Mayu
  module Server
    class PingHandlerCallback
      MOUNT_PATH = "/__mayu/ping"

      def call(env)
        request = Rack::Request.new(env)
        session_id, handler_id = request.path_info.to_s.split("/", 3).last(2)
        cookie_name = Session.cookie_name(session_id)
        session_key =
          request
            .cookies
            .fetch(cookie_name) { return 401, {}, ["Session cookie not set"] }

        payload = JSON.parse(request.body.read)

        Session.ping(session_id, session_key, payload)
      end

      [200, {}, ["ok"]]
    end
  end
end
