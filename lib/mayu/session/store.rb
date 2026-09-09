# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "errors"

module Mayu
  class Session
    class Store
      TRANSFER_CONCURRENCY = 4
      TRANSFER_TIMEOUT_SECONDS = 1
      SESSION_CLEANUP_INTERVAL_SECONDS = 1

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
            barrier = Async::Barrier.new
            semaphore =
              Async::Semaphore.new(TRANSFER_CONCURRENCY, parent: barrier)

            @sessions
              .each do |session_id, session|
                semaphore.async do |task|
                  task.with_timeout(TRANSFER_TIMEOUT_SECONDS) do
                    Console.logger.info(
                      self,
                      "Transferring session #{session_id}"
                    )
                    session.transfer!
                  rescue Async::TimeoutError
                    Console.logger.error(
                      self,
                      "Transfer of session #{session_id} timed out"
                    )
                  else
                    Console.logger.info(
                      self,
                      "Transferred session #{session_id}"
                    )
                  end
                end
              end
              .clear

            barrier.wait
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
              sleep SESSION_CLEANUP_INTERVAL_SECONDS

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

      def stop
        @cleanup_task&.stop
        @cleanup_task = nil
      end
    end
  end
end
