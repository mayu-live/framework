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

        sig {void}
        def initialize
          @connections = T.let({}, T::Hash[String, Connection])
        end

        sig {params(connection: Connection).returns(Connection)}
        def add(connection)
          @connections[connection.id] = connection
        end

        sig {params(connection_id: String).void}
        def delete(connection_id)
          @connections.delete(connection_id)
        end

        sig {void}
        def close_all!
          @connections.each_value(&:close)
          @connections.clear
        end

        sig {params(event: Symbol, payload: T.untyped).void}
        def broadcast(event, payload = {})
          @connections.keep_if do |_id, conn|
            conn.send_event(event, payload)
          end
        end
      end

      sig {returns(String)}
      attr_reader :id

      sig {void}
      def initialize
        @id = T.let(SecureRandom.uuid, String)

        @connections = T.let(Connections.new, Connections)
        @renderer = T.let(Renderer.new, Renderer)
        @renderer.start

        Async do |task|
          running = T.let(true, T::Boolean)

          while @renderer.running?
            p "hello"
            message = @renderer.take
            p [:message, message]

            case message
            in :html, payload
              @connections.broadcast(:html, payload)
            in :close
              @connections.close_all!
              running = T.let(false, T::Boolean)
            else
              puts "Unnhandled: #{message.inspect}"
            end
          end
        end

        puts "done initializing"
      end

      sig {returns(String)}
      def render
        ""
      end

      SESSIONS = T.let({}, T::Hash[String, self])

      sig {returns(Types::TRackReturn)}
      def self.init
        session = new
        SESSIONS[session.id] = session
        session.rack_response
      end

      sig {returns(Types::TRackReturn)}
      def rack_response
        [
          200,
          {'content-type' => 'text/html; charset=utf-8'},
          [@renderer.html.prepend("<!DOCTYPE html>\n")]
        ]
      end

      sig {params(session_id: String).returns(Types::TRackReturn)}
      def self.connect(session_id)
        session = SESSIONS.fetch(session_id)
        session.connect
      end

      sig {returns(Types::TRackReturn)}
      def connect
        @connections.add(Connection.new(@id)).rack_response
      end

      sig {void}
      def close
        @renderer.stop
      end

      sig {params(handler_id: String, payload: T.untyped).void}
      def handle_event(handler_id, payload = {})
        puts "#{handler_id} #{payload.inspect}"
      end
    end
  end
end
