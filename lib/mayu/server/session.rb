# typed: strict

require "securerandom"
require_relative "connection"
require_relative "types"

class Mayu::Server::Session
  extend T::Sig
  Types = Mayu::Server::Types

  sig {returns(String)}
  attr_reader :id

  sig {void}
  def initialize
    @id = T.let(SecureRandom.uuid, String)

    @connections = T.let({}, T::Hash[String, Mayu::Server::Connection])

    @ractor = T.let(Ractor.new do
      running = T.let(true, T::Boolean)

      while running do
        case message = Ractor.receive
        in :render
          html = ""
          Ractor.yield([:event, :html, html])
        in :close
          Ractor.yield(:close)
          running = false
        else
          puts "Invalid message: #{message.inspect}"
        end
      end
    end, Ractor)

    Async do |task|
      running = true

      while message = @ractor.take
        case message
        in :event, event, payload
          @connections.delete_if do |id, conn|
            if conn.closed?
              true
            else
              conn.send_event(event, payload)
              false
            end
          end
        in :close
          @connections.each_value(&:close)
          @connections.clear
        end
      end
    end
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
    body = ""
    [200, {'content-type' => 'text/html; charset=utf-8'}, [body]]
  end

  sig {params(session_id: String).returns(Types::TRackReturn)}
  def self.connect(session_id)
    session = SESSIONS.fetch(session_id)
    session.connect
  end

  sig {returns(Types::TRackReturn)}
  def connect
    connection = Mayu::Server::Connection.new(@id)
    @connections[connection.id] = connection
    connection.rack_response
  end

  sig {void}
  def close
    @ractor.send(:close)
  end

  sig {params(handler_id: String, payload: T.untyped).void}
  def handle_event(handler_id, payload = {})
    puts "#{handler_id} #{payload.inspect}"
  end
end
