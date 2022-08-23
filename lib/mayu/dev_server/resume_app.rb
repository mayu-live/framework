# typed: false

require_relative "session"

module Mayu
  module DevServer
    class ResumeApp
      MOUNT_PATH = "/__mayu/resume"

      def call(env)
        request = Rack::Request.new(env)
        location = request.params[:path] || "/"
        cookie_name = Session.cookie_name(session_id)
        session_key =
          request
            .cookies
            .fetch(cookie_name) { return 401, {}, ["Session cookie not set"] }
        Console.logger.info(self) { "Resuming not implemented yet!!" }
        return 302, { "location" => location }, ["resuming not implemented"]
      end
    end
  end
end
