# typed: strict

require "async/queue"
require_relative "types"
require_relative "monkeypatches"

module Mayu
  module Server
    class Connection
      extend T::Sig

      sig { params(session_id: String).returns(Types::TRackReturn) }
      def self.call(session_id)
        new(session_id).rack_response
      end

      sig { returns(String) }
      attr_reader :id

      sig { params(session_id: String, task: Async::Task).void }
      def initialize(session_id, task: Async::Task.current)
        @id = T.let(SecureRandom.uuid, String)
        @session_id = session_id
        @body =
          T.let(Async::HTTP::Body::Writable.new, Async::HTTP::Body::Writable)
        @queue = T.let(Async::Queue.new, Async::Queue)

        @task =
          T.let(
            task.async do
              loop { @body.write(@queue.dequeue.to_s) }
            rescue => e
              puts e.message
              close
              raise
            end,
            Async::Task
          )
      end

      sig { params(id: String, event: Symbol, payload: T.untyped).void }
      def send_event(id, event, payload = {})
        data = "id: #{id}\nevent: #{event}\ndata: #{JSON.generate(payload)}\n\n"
        @queue.enqueue(data)
      end

      sig { returns(Types::TRackReturn) }
      def rack_response
        [200, { "content-type" => "text/event-stream; charset=utf-8" }, @body]
      end

      sig { void }
      def close
        @body.close
        @task.stop
      end

      sig { returns(T::Boolean) }
      def closed? = @body.closed?
    end
  end
end
