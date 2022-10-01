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

      sig { returns(Integer) }
      def count
        @sessions.count
      end

      sig { params(metrics: Metrics, task: Async::Task).returns(Async::Task) }
      def start_cleanup_task(metrics:, task: Async::Task.current)
        task.async do
          cleanup_time = 5.0

          loop do
            keys = @sessions.keys
            metrics.session_count.set(keys.size)

            Console.logger.warn(
              self,
              "Running expiration loop with #{keys.length} keys"
            )

            if keys.empty?
              sleep(cleanup_time)
            else
              sleep_time = cleanup_time / keys.length

              keys.each do |key|
                session = @sessions[key]

                next unless session

                if session.expired?
                  Console.logger.warn(self, "Expiring #{session.id}")
                  @sessions.delete(key)
                  session.stop!
                else
                  puts format(
                         "%s responded %.2fs ago",
                         session.id,
                         session.seconds_since_last_ping
                       )
                end
              ensure
                sleep(sleep_time)
              end
            end
          end
        end
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
        Session.validate_id!(session_id)

        Digest::SHA256.digest(
          Digest::SHA256.digest(session_id) + Digest::SHA256.digest(token)
        )
      end
    end
  end
end
