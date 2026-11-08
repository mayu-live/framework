# frozen_string_literal: true

Identity = import("/lib/Identity.rb")
OIDC = import("/lib/OIDC.rb")

def GET(request)
  Identity.default.login(popup: request.query["popup"] == "1")
rescue OIDC::Error => error
  ::Console.logger.warn(self, error.message)
  Identity.default.failure(popup: request.query["popup"] == "1")
end
