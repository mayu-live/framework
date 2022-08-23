# typed: strict

require "securerandom"
require "async"
require "async/semaphore"
require "async/barrier"
require "async/io/trap"
require "cgi"
require_relative "message_cipher"
require_relative "renderer"
require_relative "session"

module Mayu
  module Server
    module Worker
      extend T::Sig

      sig { params(cluster: Cluster, metrics: Metrics, config: Config).void }
      def self.start(cluster:, metrics:, config:)
        logger = cluster.logger
        message_cipher = MessageCipher.new(key: config.SECRET_KEY)

        Async do |task|
          barrier = Async::Barrier.new
          semaphore = Async::Semaphore.new(config.MAX_SESSIONS, parent: barrier)
          print_capacity = Async::Condition.new

          interrupt = Async::IO::Trap.new(:INT)
          interrupt.install!

          task.async do |subtask|
            sleep(rand * config.PRINT_CAPACITY_INTERVAL)

            loop do
              logger.info(
                format(
                  "Workers in use: %d/%d",
                  semaphore.count,
                  semaphore.limit
                )
              ) do
                Console::Event::Progress.new(semaphore.count, semaphore.limit)
              end

              metrics.session_count.set(semaphore.count)
              metrics.session_limit.set(semaphore.limit)

              subtask.with_timeout(config.PRINT_CAPACITY_INTERVAL) do
                print_capacity.wait
              rescue Async::TimeoutError
                # We timed out, so we print the capacity again
              end
            end
          end

          subscribe_task =
            task.async do
              loop do
                cluster
                  .workers
                  .subscribe(queue: "worker") do |msg|
                    throw :unsubscribe if semaphore.blocking?

                    case msg.data
                    in [:init, { path:, query: }]
                      metrics.worker_queue_messages.increment(
                        labels: {
                          event: :init
                        }
                      )

                      semaphore.async do |subtask|
                        started_at = Time.now
                        session = Session.init(cluster)

                        logger.info("Inititalizing #{session.id}")

                        msg.respond(html: session.initial_html(message_cipher))

                        logger.info(
                          "Done initializing #{session.id} after %.1fs" %
                            (Time.now - started_at)
                        )
                      end
                    in [:resume, { encrypted_state: }]
                      metrics.worker_queue_messages.increment(
                        labels: {
                          event: :resume
                        }
                      )

                      semaphore.async do |subtask|
                        started_at = Time.now
                        state = message_cipher.load(encrypted_state)
                        session = Session.resume(cluster, state)

                        logger.info("Resuming #{session.id}")

                        msg.respond(id: session.id, token: session.token)

                        session_loop(
                          session,
                          metrics:,
                          logger:,
                          interrupt:,
                          config:,
                          task: subtask
                        )
                      ensure
                        if session
                          logger.info(
                            "Ending session #{session.id} after %.1fs" %
                              (Time.now - started_at)
                          )
                        end
                      end
                    in [
                         :transfer,
                         { session: { id:, token:, state: }, connection_id: }
                       ]
                      semaphore.async do |subtask|
                        session = Session.new(cluster, id:, token:, state:)

                        logger.info("Resuming transferred #{session.id}")

                        #  msg.respond(status: :ok, alloc_id: cluster.alloc_id)

                        session_loop(
                          session,
                          metrics:,
                          logger:,
                          interrupt:,
                          config:,
                          connection_id:,
                          task: subtask
                        )
                      end
                    end

                    print_capacity.signal
                    throw :unsubscribe if semaphore.blocking?
                  end
                  .wait

                logger.warn(
                  "Waiting for connections to close before resubscribing"
                )

                semaphore.send(:wait)
              end
            ensure
              logger.warn("Stopped the global subscription")
            end

          task.async do |subtask|
            interrupt.wait

            logger.error("Interrupt", "Stopping subscriptions")

            subscribe_task.stop

            next if barrier.empty?

            barrier.wait
            interrupt.default!
          end
        end
      end

      sig do
        params(
          session: Session,
          metrics: Metrics,
          interrupt: Async::IO::Trap,
          config: Config,
          connection_id: T.nilable(String),
          task: Async::Task,
          logger: T.untyped
        ).returns(Async::Task)
      end
      def self.session_loop(
        session,
        metrics:,
        interrupt:,
        config:,
        connection_id: nil,
        task: Async::Task.current,
        logger: Console.logger
      )
        on_finish = Async::Condition.new
        barrier = Async::Barrier.new

        barrier.async do
          session
            .renderer
            .run do |message|
              if connection_id
                session
                  .cluster
                  .connection(connection_id)
                  .publish([:patch, message])
              end
            end
            .wait
        ensure
          logger.debug("Session #{session.id}", "Stopping RENDER task")
          on_finish.signal()
        end

        barrier.async do
          last_heartbeat_at = Time.now.to_f

          loop do
            sleep config.HEARTBEAT_INTERVAL_SECONDS

            time_passed = Time.now.to_f - last_heartbeat_at

            if time_passed > config.KEEPALIVE_SECONDS / 2
              logger.info("Timeout") do
                Console::Event::Progress.new(
                  [time_passed, config.KEEPALIVE_SECONDS].min,
                  config.KEEPALIVE_SECONDS
                )
              end
            end

            if time_passed > config.KEEPALIVE_SECONDS
              metrics.session_timeout.increment
              logger.warn("Session #{session.id}", "Timed out")
              on_finish.signal()
              break
            end

            if connection_id
              session.cluster.connection(connection_id).publish(:heartbeat)
              last_heartbeat_at = Time.now.to_f
              metrics.session_heartbeats.increment
            end
          end
        ensure
          logger.debug("Session #{session.id}", "Stopping HEARTBEAT task")
          on_finish.signal()
        end

        barrier.async do |subtask|
          session
            .subject
            .subscribe do |msg|
              case msg.data
              in [:ping, timestamp]
                logger.debug("Session #{session.id}", "Ping")
                msg.respond(
                  timestamp:,
                  region: session.cluster.region,
                  alloc_id: session.cluster.alloc_id
                )
                metrics.session_callbacks.increment
              in [:handle_callback, event_handler_id, payload]
                msg.respond(:ok)
                metrics.session_callbacks.increment
              in [:connect, new_connection_id]
                if connection_id
                  begin
                    logger.warn(
                      "Session #{session.id}",
                      "Closing old connection: #{connection_id}"
                    )

                    session.cluster.connection(connection_id).publish(:close)
                  rescue StandardError
                    nil
                  end
                end

                logger.info(
                  "Session #{session.id}",
                  "New connection: #{new_connection_id}"
                )

                connection_id = T.let(new_connection_id, String)
                msg.respond(:ok)

                metrics.session_connect.increment
              in [:disconnect, disconnected_connection_id]
                next unless connection_id == disconnected_connection_id

                logger.info(
                  "Session #{session.id}",
                  "User disconnected: #{connection_id}"
                )

                connection_id = nil
                metrics.session_disconnect.increment
              end
            end
            .wait
        ensure
          on_finish.signal()
          logger.warn("Session #{session.id}", "Stopping SUBSCRIBE task")
        end

        task.async do
          interrupt.wait

          logger.warn("Session #{session.id}", "Stopping task")

          # I feel like I'm doing some funky stuff here.
          # Stopping the same task?
          task.stop

          logger.warn("Session #{session.id}", "Waiting for subtasks to stop")

          # Everything else has to stop so that we can transfer the state..
          barrier.wait

          if connection_id
            logger.info("Session #{session.id}", "Transferring state")

            session.cluster.workers.publish(
              [:transfer, { session: session.transfer_data, connection_id: }]
            )

            logger.info("Session #{session.id}", "Transferred state")
          end
        end

        on_finish.wait
        task.stop
      end
    end
  end
end
