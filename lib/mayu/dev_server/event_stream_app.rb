# typed: false

require_relative "session"

module Mayu
  module DevServer
    class EventStreamApp
      MOUNT_PATH = "/__mayu/events"

      EVENT_STREAM_HEADERS = {
        "content-type" => "text/event-stream; charset=utf-8",
        "cache-control" => "no-cache",
        "x-accel-buffering" => "no"
      }

      def call(env)
        request = Rack::Request.new(env)
        session_id = request.path_info.to_s.split("/", 2).last
        cookie_name = Session.cookie_name(session_id)

        session_key =
          request
            .cookies
            .fetch(cookie_name) { return 401, {}, ["Session cookie not set"] }

        case Session.connect(session_id, session_key)
        in :session_not_found
          [404, {}, ["Session not found"]]
        in :bad_session_key
          [403, {}, ["Bad session key"]]
        in :too_many_connections
          [429, {}, ["Too many connections"]]
        in Async::HTTP::Body::Writable => body
          [200, EVENT_STREAM_HEADERS, body]
        else
          [500, {}, ["Internal server error"]]
        end
      end
    end
  end
end
