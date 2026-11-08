# frozen_string_literal: true

Identity = import("./lib/Identity.rb")

# This snapshot is available as session_context in components and survives live
# navigation and worker transfers. A new document gets a new snapshot.
def self.prepare_session(request)
  {started_at: Time.now.to_i, **Identity.default.context(request.headers)}
end

# Anonymous sessions remain public. Signed-in snapshots expire after 15 minutes;
# HTTP transport requests also check that the browser still has the same login.
def self.authorize_session(session, request: nil)
  unless Identity.default.authorized?(session.context, request:)
    raise Mayu::Session::Rejected.new(location: Identity::PAGE)
  end
  true
end

# Request wrappers also run for HTTP handlers, assets, and session transports.
def self.around_request(request, next_app)
  response = next_app.call(request)
  response.headers["referrer-policy"] ||= "strict-origin"
  response.headers["cache-control"] = "no-store" if response.headers["content-type"].to_s.include?("text/html")
  response
end
