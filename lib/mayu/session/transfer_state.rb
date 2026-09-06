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
            state:
              Runtime::Marshalling.with_component_resolver(
                session.component_resolver
              ) { Marshal.dump(session) }
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

        def resume(environment)
          provider = environment.module_provider if environment.respond_to?(
            :module_provider
          )
          resolver = provider.component_resolver if provider&.respond_to?(
            :component_resolver
          )
          Runtime::Marshalling.with_component_resolver(resolver) do
            Marshal.load(state).resume_transferred(environment)
          end
        end
      end
  end
end
