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

        sig { void }
        def initialize
          @connections = T.let({}, T::Hash[String, Connection])
        end

        sig { params(connection: Connection).returns(Connection) }
        def add(connection)
          @connections[connection.id] = connection
        end

        sig { params(connection_id: String).void }
        def delete(connection_id)
          @connections.delete(connection_id)
        end

        sig { void }
        def close_all!
          @connections.each_value(&:close)
          @connections.clear
        end

        sig { params(event: Symbol, payload: T.untyped).void }
        def broadcast(event, payload = {})
          @connections.keep_if do |_id, conn|
            conn.send_event(event, payload)
          rescue => e
            puts "hello"
            p e
          end
        end
      end

      TIMEOUT_SECONDS = 120.0

      sig { returns(String) }
      attr_reader :id

      sig { params(task: Async::Task).void }
      def initialize(task: Async::Task.current)
        @id = T.let(SecureRandom.uuid, String)
        @connections = T.let(Connections.new, Connections)
        @disconnected_at = T.let(Time.now, T.nilable(Time))

        @task = T.let(
          task.async(annotation: "Session #{@id}") do |subtask|
            loop do
              if @disconnected_at
                diff = Time.now - @disconnected_at

                if diff > TIMEOUT_SECONDS
                  puts "Stopping everything"
                  subtask.stop
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
            p "hello"
            message = @renderer.take
            p [:message, message]

            case message
            in [:html, payload]
              @connections.broadcast(:html, payload)
            in [:patch_set, payload]
              @connections.broadcast(:patch_set, payload)
            in :close
              @connections.close_all!
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
        p "initialized session"
        p SESSIONS.keys
        session.rack_response
      end

      sig { returns(Types::TRackReturn) }
      def rack_response
        html = @renderer.html
        id_tree = @renderer.id_tree

        script_id = "mayu-init-#{SecureRandom.alphanumeric(16)}"

        script = <<~EOF
        <script type="module" id="#{script_id}">
          document.getElementById("#{script_id}")?.remove()
          import Mayu from '/__mayu/live.js'
          window.Mayu = new Mayu("#{@id}", #{JSON.generate(id_tree)})
        </script>
        EOF

        [
          200,
          { "content-type" => "text/html; charset=utf-8" },
          [
            html
              .prepend("<!DOCTYPE html>\n")
              .sub(%r{.*\K</body>}) { "#{script.strip}#{_1}" }
          ]
        ]
      end

      sig { params(session_id: String).returns(Types::TRackReturn) }
      def self.connect(session_id)
        session =
          SESSIONS.fetch(session_id) do
            raise KeyError,
                  "Session not found: #{session_id}, has: #{SESSIONS.keys.inspect}"
          end
        session.connect
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

      sig { returns(Types::TRackReturn) }
      def connect
        @disconnected_at = nil
        @connections.add(Connection.new(@id)).rack_response
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
