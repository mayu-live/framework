# typed: true

module Mayu
  module DevServer
    class EdgeEnv
      class Subject
        def initialize(nats, subject)
          @nats = nats
          @subject = subject
        end

        def to_s
          @subject
        end

        def request(*data)
          Console.logger.warn("Requesting from", @subject)
          Message.new(
            @nats.request(@subject, T.unsafe(MessagePack).pack(*data))
          )
        end

        def publish(*data)
          Console.logger.warn("Publishing to", @subject)
          @nats.publish(@subject, T.unsafe(MessagePack).pack(*data))
        end

        def subscribe(task: Async::Task.current, **options, &block)
          Console.logger.warn("Subscribing to", @subject)

          @nats.subscribe(@subject, **options) { |msg| yield Message.new(msg) }
        end

        class Message
          def initialize(msg)
            @msg = msg
          end

          def data
            @data ||= MessagePack.unpack(@msg.data)
          end

          def respond(*args)
            @msg.respond(T.unsafe(MessagePack).pack(*args))
          end
        end
      end

      attr_reader :alloc_id
      attr_reader :region

      def initialize(nats:, region: "dev", alloc_id: SecureRandom.uuid)
        @nats = nats
        @alloc_id = alloc_id
        @region = region
      end

      def type = :server
      def app_name = :mayu_dev

      def inspect
        "#<#{self.class.name} #{type}.#{region}.#{alloc_id}>"
      end

      def session_cookie_name(session_id)
        "mayu-session-#{session_id}"
      end

      def session(session_id, token)
        Subject.new(
          @nats,
          build_subject(:session, session_hash(session_id, token))
        )
      end

      def connection(connection_id)
        Subject.new(@nats, build_subject(:connection, connection_id))
      end

      def workers
        Subject.new(@nats, build_subject(:workers))
      end

      private

      def session_hash(session_id, token)
        Digest::SHA256.hexdigest(
          Digest::SHA256.digest(session_id.to_s) +
            Digest::SHA256.digest(token.to_s)
        )
      end

      def build_subject(type, *rest)
        [:mayu, type, *rest].join(".")
      end
    end
  end
end
