# typed: strict
# frozen_string_literal: true

module Mayu
  module Server
    class Sessions
      extend T::Sig

      class NotFoundError < StandardError
      end

      class AlreadyRunningError < StandardError
      end

      sig { void }
      def initialize
        @sessions = T.let({}, T::Hash[String, Session])
      end

      sig { void }
      def rerender
        @sessions.values.each(&:rerender)
      end

      sig { params(session: Session).void }
      def add(session)
        session_key = session_key(session.id, session.token)

        if @sessions.include?(session_key)
          raise AlreadyRunningError, "Session #{session} has already been added"
        end

        @sessions.store(session_key, session)
      end

      sig { params(id: String, token: String).returns(T::Boolean) }
      def include?(id, token)
        @sessions.include?(session_key(id, token))
      end

      sig { params(id: String, token: String).returns(Session) }
      def fetch(id, token)
        @sessions.fetch(session_key(id, token)) do
          raise NotFoundError, "Session #{id} not found (or invalid token)"
        end
      end

      sig { params(id: String, token: String).void }
      def delete(id, token)
        @sessions.delete(session_key(id, token))
      end

      sig { params(session_id: String, token: String).returns(String) }
      def session_key(session_id, token)
        Digest::SHA256.digest(
          Digest::SHA256.digest(session_id) + Digest::SHA256.digest(token)
        )
      end
    end
  end
end
