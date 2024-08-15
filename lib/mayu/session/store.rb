# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "errors"

module Mayu
  class Session
    class Store
      def initialize(metrics:)
        @metrics = metrics
        @sessions = {}
      end

      def store(session)
        @sessions[session.id] = session
      end

      def authenticate!(id, token)
        session = @sessions.fetch(id) { raise Errors::SessionNotFoundError }

        raise Errors::InvalidTokenError unless session.valid_token?(token)

        session
      end

      def transfer_all
        return if @sessions.empty?

        Console.logger.info(
          self,
          format("\e[1;33mTRANSFERRING %d SESSIONS\e[0m", @sessions.size)
        )

        elapsed =
          Async::Clock.measure do
            @sessions.each { |session_id, session| session.transfer! }.clear
          end

        Console.logger.info(
          self,
          format("\e[32mTRANSFERRED SESSIONS IN %.2f SECONDS\e[0m", elapsed)
        )
      end

      def delete(session_id)
        @sessions.delete(session_id)
      end

      def start_cleanup_task(timeout)
        @cleanup_task ||=
          Async do
            loop do
              sleep 1

              @sessions.delete_if do |session_id, session|
                if session.timed_out?(timeout)
                  Console.logger.info(
                    self,
                    "\e[31mDeleting timed out session #{session_id}\e[0m"
                  )
                  session.stop
                  @metrics.session_timeout_count.increment
                  true
                end
              end

              @metrics.session_count.set(@sessions.size)
            end
          end
      end
    end
  end
end
