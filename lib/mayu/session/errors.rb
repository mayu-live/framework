# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  class Session
    module Errors
      class SessionIdMismatchError < StandardError
      end
      class SessionNotFoundError < StandardError
      end
      class InvalidTokenError < StandardError
      end
    end
  end
end
