# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  class Server
    class SessionStore
      class SessionNotFoundError < StandardError
      end
      class InvalidTokenError < StandardError
      end

      def initialize
        @sessions = {}
      end

      def store(session)
        @sessions[session.id] = session
      end

      def authenticate(id, token)
        session = @sessions.fetch(id) { raise SessionNotFoundError }

        unless Session::Token.equal?(session.token, token)
          raise InvalidTokenError
        end

        session
      end

      def transfer_all
        @sessions.each do |session_id, session|
          session.transfer!
          delete(session_id)
        end
      end

      def delete(session_id)
        @sessions.delete(session_id)
      end

      def start_cleanup_task
        @cleanup_task ||=
          Async do
            loop do
              sleep 1

              @sessions.delete_if do |session_id, session|
                if session.timed_out?
                  puts "\e[31mDeleting timed out session #{session_id}\e[0m"
                  session.stop
                  true
                end
              end
            end
          end
      end
    end
  end
end
