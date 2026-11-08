# frozen_string_literal: true

Identity = import("/lib/Identity.rb")
def GET(request)
  Identity.default.callback(request.query, request.headers)
end
