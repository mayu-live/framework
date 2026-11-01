# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "token"
require_relative "context"
require_relative "errors"

module Mayu
  class Session
    TransferState =
      Data.define(:id, :token, :state, :version, :info) do
        def initialize(id:, token:, state:, version: 1, info: nil)
          super
        end

        def self.from_session(session)
          new(
            id: session.id,
            token: session.token,
            version: 1,
            info: session.info,
            state:
              Runtime::Marshalling.with_component_resolver(
                session.component_resolver
              ) { Marshal.dump(session) }
          )
        end

        def authenticate!(session_id:, session_token:)
          raise Errors::SessionIdMismatchError unless id == session_id

          unless Token.equal?(token, session_token)
            raise Errors::InvalidTokenError
          end

          self
        end

        def self.decrypt(marshaller, encrypted_state)
          marshaller.load(encrypted_state) => self => state
          if state.info.is_a?(Info)
            state = state.with(info: Info.new(id: state.info.id, path: state.info.path, context: state.info.context))
          end
          state
        end

        def encrypt(marshaller) = marshaller.dump(self)

        def validate_metadata!
          unless version == 1 && info.is_a?(Info) && info.id == id
            raise ArgumentError, "Unsupported session transfer metadata"
          end
          self
        end

        def resume(environment)
          validate_metadata!
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
