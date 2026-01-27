# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "token"
require_relative "errors"

module Mayu
  class Session
    TransferState =
      Data.define(:id, :token, :state) do
        def self.from_session(session)
          new(
            id: session.id,
            token: session.token,
            state: Marshal.dump(session)
          )
        end

        def authenticate!(session_id:, session_token:)
          raise Errors::SessionIdMismatchError unless self.id == session_id

          unless Token.equal?(self.token, session_token)
            raise Errors::InvalidTokenError
          end

          self
        end

        def self.decrypt(marshaller, encrypted_state)
          marshaller.load(encrypted_state) => self => state
          state
        end

        def encrypt(marshaller) = marshaller.dump(self)

        def resume(environment) =
          Marshal.load(state).resume_transferred(environment)
      end
  end
end
