# typed: strict

require_relative "types"

module Mayu
  module Server
    class Connection
      extend T::Sig

      sig {params(session_id: String).returns(Types::TRackReturn)}
      def self.call(session_id)
        new(session_id).rack_response
      end

      sig {returns(String)}
      attr_reader :id

      sig {params(session_id: String).void}
      def initialize(session_id)
        @id = T.let(SecureRandom.uuid, String)
        @session_id = session_id
        @body = T.let(Async::HTTP::Body::Writable.new, Async::HTTP::Body::Writable)

        @ractor = T.let(Ractor.new(@body) do |body|
          running = true

          until body.closed?
            body.write(Ractor.receive)
          end
        end, Ractor)
      end

      sig {params(event: Symbol, payload: T.untyped).void}
      def send_event(event, payload = {})
        data = "event: #{event}\ndata: #{JSON.generate(payload)}\n\n"
        @ractor.send(data)
      end

      sig {returns(Types::TRackReturn)}
      def rack_response
        [200, {'content-type' => 'text/event-stream; charset=utf-8'}, [@body]]
      end

      sig {void}
      def close = @body.close

      sig {returns(T::Boolean)}
      def closed? = @body.closed?
    end
  end
end
