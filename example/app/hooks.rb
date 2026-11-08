# frozen_string_literal: true

# This snapshot is available as session_context in components and survives live
# navigation and worker transfers. A new document gets a new snapshot.
def self.prepare_session(_request)
  {started_at: Time.now.to_i}
end

# The demo is public. An authenticated app can import its identity service here
# and check session.context[:identity_id] against its current validity policy.
def self.authorize_session(_session)
  true
end

# Request wrappers also run for HTTP handlers, assets, and session transports.
def self.around_request(request, next_app)
  response = next_app.call(request)
  response.headers["referrer-policy"] = "strict-origin"
  response
end
