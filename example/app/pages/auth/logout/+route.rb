# frozen_string_literal: true

Identity = import("/lib/Identity.rb")

# Mayu's ordinary same-origin request protection applies to this POST.
def POST(_request)
  Identity.default.logout
end
