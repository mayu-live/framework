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

      sig do
        params(environment: Environment, metrics: Metrics, config: Config).void
      end
      def self.start(environment:, metrics:, config:)
        logger = environment.cluster.logger
        message_cipher = MessageCipher.new(key: config.SECRET_KEY)

        Async do |task|
          barrier = Async::Barrier.new
          semaphore = Async::Semaphore.new(config.MAX_SESSIONS, parent: barrier)
          print_capacity = Async::Condition.new

          interrupt = Async::IO::Trap.new(:INT)
          # interrupt.install!

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
                environment
                  .cluster
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
                        session = Session.init(environment)

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
                        session = Session.resume(environment, state)

                        logger.info("Resuming #{session.id}")

                        msg.respond(id: session.id, token: session.token)

                        session_loop(
                          environment,
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
                        session = Session.new(environment, id:, token:, state:)

                        logger.info("Resuming transferred #{session.id}")

                        #  msg.respond(status: :ok, alloc_id: environment.cluster.alloc_id)

                        session_loop(
                          environment,
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

            logger.error("Interrupt", "Stopped subscriptions")

            unless barrier.empty?
              subtask.with_timeout(5) do
                barrier.wait
              rescue Async::TimeoutError
                interrupt.default!
              end
            end
          end
        end
      end

      sig do
        params(
          environment: Environment,
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
        environment,
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
          q = Async::Queue.new

          session
            .renderer
            .run do |message|
              unless connection_id
                q.enqueue(message)
                next
              end

              until q.empty?
                environment
                  .cluster
                  .connection(connection_id)
                  .publish([:send, q.dequeue])
              end

              environment
                .cluster
                .connection(connection_id)
                .publish([:send, message])
            end
            .wait

          logger.warn("DONE WAITING FOR RENDE")
        rescue => e
          Console.logger.error(e)
          puts e.backtrace
          raise
        ensure
          logger.debug("Session #{session.id}", "Stopping RENDER task")
          on_finish.signal(:render)
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
              on_finish.signal(:timeout)
              break
            end

            if connection_id
              environment.cluster.connection(connection_id).publish(:heartbeat)
              last_heartbeat_at = Time.now.to_f
              metrics.session_heartbeats.increment
            end
          end
        ensure
          logger.debug("Session #{session.id}", "Stopping HEARTBEAT task")
          on_finish.signal(:heartbeat)
        end

        barrier.async do |subtask|
          Console.logger.warn("Starting subscribe")
          session
            .subject
            .subscribe do |msg|
              Console.logger.warn("message", msg.data.inspect)
              case msg.data
              in [:ping, timestamp]
                logger.debug("Session #{session.id}", "Ping")
                response = {
                  timestamp:,
                  region: environment.cluster.region,
                  alloc_id: environment.cluster.alloc_id
                }
                if connection_id
                  environment
                    .cluster
                    .connection(connection_id)
                    .publish([:send, [:pong, response]])
                end
                msg.respond(response)
                metrics.session_callbacks.increment
              in [:handle_callback, event_handler_id, payload]
                begin
                  session.renderer.handle_callback(event_handler_id, payload)
                rescue => e
                  Console.logger.error(self, e)
                end
                msg.respond(:ok)
                metrics.session_callbacks.increment
              in [:connect, new_connection_id]
                if connection_id
                  begin
                    logger.warn(
                      "Session #{session.id}",
                      "Closing old connection: #{connection_id}"
                    )

                    environment
                      .cluster
                      .connection(connection_id)
                      .publish(:close)
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

          Console.logger.fatal(self, "done waiting!!")
        rescue => e
          Console.logger.fatal(e)
          raise
        ensure
          on_finish.signal(:subscribe)
          logger.warn("Session #{session.id}", "Stopping SUBSCRIBE task")
        end

        task.parent.async do
          logger.warn("WAITING FOR INTERRUTP")
          interrupt.wait

          logger.warn("GOT INTERRUPT, STOPPING THE TASK")

          logger.warn("Session #{session.id}", "Stopping task")

          on_finish.signal(:interrupt)

          logger.warn("Session #{session.id}", "Waiting for subtasks to stop")

          # Everything else has to stop so that we can transfer the state..
          barrier.wait

          if connection_id
            logger.info("Session #{session.id}", "Transferring state")

            environment.cluster.workers.publish(
              [:transfer, { session: session.transfer_data, connection_id: }]
            )

            logger.info("Session #{session.id}", "Transferred state")
          end
        end

        reason = on_finish.wait
        Console.logger.fatal("ON FINISH CALLED", reason)
        task.stop
      end
    end
  end
end
