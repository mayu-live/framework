# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "errors"
require_relative "event"

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

      def each(&)
        @sessions.values.each(&)
      end

      def authenticate!(id, token)
        session = @sessions.fetch(id) { raise Errors::SessionNotFoundError }

        raise Errors::InvalidTokenError unless session.valid_token?(token)

        session
      end

      def transfer_all
        sessions = @sessions.values.map { |session| [session, session.running?] }
        barrier = Async::Barrier.new
        semaphore = Async::Semaphore.new(TRANSFER_CONCURRENCY, parent: barrier)

        sessions.each do |session, connected|
          semaphore.async do |task|
            if connected
              begin
                task.with_timeout(TRANSFER_TIMEOUT_SECONDS) { session.transfer! }
                Console.logger.info(self, event: Mayu::Session::Event.new(:transfer_queued, session_id: session.id))
              rescue => error
                Console.logger.warn(self, "Session transfer failed for #{session.id}", exception: error)
                session.transfer_failed!
              end
            else
              session.stop
            end
            @sessions.delete(session.id)
          end
        end
        barrier.wait
      ensure
        barrier&.stop
      end

      def abort
        stop
        @sessions.values.each(&:stop)
      ensure
        @sessions.clear
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
                  Console.logger.info(self, event: Mayu::Session::Event.new(:timed_out, session_id:))
                  session.stop
                  @metrics.session_timeouts_total.increment
                  true
                end
              end

              @metrics.active_sessions.set(@sessions.size)
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
