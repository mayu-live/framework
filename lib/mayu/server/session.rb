# typed: strict

require "securerandom"
require_relative "connection"
require_relative "types"
require_relative "../renderer"

module Mayu
  module Server
    class Session
      extend T::Sig

      class Connections
        extend T::Sig

        Event = T.type_alias { { id: String, event: Symbol, payload: T.untyped } }

        sig { void }
        def initialize
          # Connections shouldn't have to be stored here...
          # They can just subscribe to the notification thing.
          # And to keep the session running, we could use something like this:
          # https://github.com/socketry/async/blob/main/lib/async/barrier.rb
          @connections = T.let({}, T::Hash[String, Connection])
          # TODO: events should not be stored for the entire session.
          # Should probably be stored in redis with some timeout maybe.
          @events = T.let([], T::Array[Event])
        end

        sig { params(connection: Connection, last_event_id: T.nilable(String)).returns(Connection) }
        def add(connection, last_event_id: nil)
          @connections[connection.id] = connection
          send_missed_events(connection, last_event_id)
        end

        sig { params(connection_id: String).void }
        def delete(connection_id)
          @connections.delete(connection_id)
        end

        sig { returns(T::Boolean) }
        def empty? = @connections.empty?

        sig { void }
        def close_all!
          @connections.each_value(&:close)
          @connections.clear
        end

        sig { params(event: Symbol, payload: T.untyped).void }
        def broadcast(event, payload = {})
          id = SecureRandom.uuid
          @events.push({ id:, event:, payload: })

          @connections.keep_if do |connection_id, conn|
            next false if conn.closed?
            conn.send_event(id, event, payload)
          rescue => e
            puts "\e[31mDELETING\e[0m"
            delete(connection_id)
          end
        end

        private

        sig { params(connection: Connection, last_event_id: T.nilable(String)).returns(Connection) }
        def send_missed_events(connection, last_event_id)
          get_events_since(last_event_id).each_with_index do |message, i|
            connection.send_event(message[:id], message[:event], message[:payload])
          end

          connection
        end

        sig { params(last_event_id: T.nilable(String)).returns(T::Array[Event]) }
        def get_events_since(last_event_id = nil)
          if last_event_id
            events = @events.drop_while { |message| message[:id] != last_event_id }
            _last, *missed = events
            events
          else
            @events
          end
        end
      end

      TIMEOUT_SECONDS = 2.0

      sig { returns(String) }
      attr_reader :id

      sig { params(task: Async::Task).void }
      def initialize(task: Async::Task.current)
        @id = T.let(SecureRandom.uuid, String)
        @connections = T.let(Connections.new, Connections)
        @disconnected_at = T.let(Time.now, T.nilable(Time))

        @task =
          T.let(
            task.async(annotation: "Session #{@id}") do |subtask|
              loop do
                if @disconnected_at && @connections.empty?
                  diff = Time.now - @disconnected_at

                  if diff > TIMEOUT_SECONDS
                    puts "Stopping everything"
                    @renderer.stop
                  puts "stopping task"
                    subtask.stop
                  @task.stop
                  Async::Task.current.reactor.print_hierarchy
                    break
                  end
                end

                sleep 1
              end
            end,
            Async::Task
          )

        @renderer = T.let(Renderer.new(parent: @task), Renderer)

        @task.async(annotation: "Broadcaster") do |task|
          running = T.let(true, T::Boolean)

          loop do
            message = @renderer.take

            case message
            in [:html, payload]
              @connections.broadcast(:html, payload)
            in [:patch, payload]
              @connections.broadcast(:patch, payload)
            in [:close]
              @connections.close_all!
              @renderer.stop
              running = T.let(false, T::Boolean)
            else
              puts "Unnhandled: #{message.inspect}"
            end
          end
        ensure
          puts "Stopping broadcaster"
        end

        puts "done initializing"
      end

      sig { returns(String) }
      def render
        ""
      end

      SESSIONS = T.let({}, T::Hash[String, self])

      sig { returns(Types::TRackReturn) }
      def self.init
        session = new
        SESSIONS[session.id] = session
        session.rack_response
      end

      sig { returns(Types::TRackReturn) }
      def rack_response
        html = @renderer.html
        id_tree = @renderer.id_tree
        stylesheets = @renderer.stylesheets

        script_id = "mayu-init-#{SecureRandom.alphanumeric(16)}"

        style = <<~EOF
        <style data-mayu-ignore="true">
        #{stylesheets.values.join("\n")}
        </style>
        EOF

        script = <<~EOF
        <script type="module" data-mayu-ignore="true" src="/__mayu/live.js?id=#{@id}"></script>
        EOF

        [
          200,
          { "content-type" => "text/html; charset=utf-8" },
          [
            html
              .prepend("<!DOCTYPE html>\n")
              .sub(%r{.*\K</body>}) { "#{style.strip}#{script.strip}#{_1}" }
          ]
        ]
      end

      sig { params(session_id: String, last_event_id: T.nilable(String)).returns(Types::TRackReturn) }
      def self.connect(session_id, last_event_id: nil)
        session =
          SESSIONS.fetch(session_id) do
            raise KeyError,
                  "Session not found: #{session_id}, has: #{SESSIONS.keys.inspect}"
          end
        session.connect(last_event_id:)
      end

      sig do
        params(
          session_id: String,
          handler_id: String,
          payload: T.untyped
        ).returns(Types::TRackReturn)
      end
      def self.handle_event(session_id, handler_id, payload = {})
        session = SESSIONS.fetch(session_id)
        session.handle_event(handler_id, payload)
        [200, {}, ["ok"]]
      end

      sig { params(last_event_id: T.nilable(String)).returns(Types::TRackReturn) }
      def connect(last_event_id: nil)
        # @disconnected_at = nil
        @connections.add(Connection.new(@id), last_event_id:).rack_response
      end

      sig { void }
      def close
        @renderer.stop
      end

      sig { params(handler_id: String, payload: T.untyped).returns(T::Boolean) }
      def handle_event(handler_id, payload = {})
        @renderer.send(:handle_event, handler_id, payload)
        true
      end
    end
  end
end
