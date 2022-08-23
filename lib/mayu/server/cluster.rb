# typed: strict
require "bundler/setup"
require "nats/client"
require "securerandom"
require "msgpack"
# require "pry"
require "console/logger"

MessagePack::DefaultFactory.register_type(0x00, Symbol)

module Mayu
  module Server
    class Cluster
      class Subject
        extend T::Sig

        sig { params(nats: NATS::IO::Client, subject: String).void }
        def initialize(nats, subject)
          @nats = nats
          @subject = subject
        end

        sig { returns(String) }
        def to_s
          @subject
        end

        sig { params(data: T.untyped).returns(Message) }
        def request(*data)
          Message.new(
            @nats.request(@subject, T.unsafe(MessagePack).pack(*data))
          )
        end

        sig { params(data: T.untyped).void }
        def publish(*data)
          @nats.publish(@subject, T.unsafe(MessagePack).pack(*data))
        end

        # This implementation works with https://github.com/socketry/async
        # Without this, it says something about resuming a fiber from a different
        # thread, which is probably due to the NATS client running the callbacks
        # in a different thread...
        # Anyways, it was pretty easy just to push all messages to a Thread::Queue
        # which is thread-safe, and then just pull messages from that queue in an
        # Async::Task.
        sig do
          params(
            task: Async::Task,
            options: T.untyped,
            block: T.proc.params(arg0: T.untyped).void
          ).returns(Async::Task)
        end
        def subscribe(task: Async::Task.current, **options, &block)
          queue = Thread::Queue.new

          sub =
            @nats.subscribe(@subject, **options) do |msg|
              queue.enq(Message.new(msg))
            rescue => e
              Console.logger.fatal(self) { e }
            end

          task.async do |subtask|
            catch :unsubscribe do
              loop { block.call(queue.deq) }
            end
          ensure
            sub&.unsubscribe
          end
        end

        sig { returns(String) }
        def inspect
          "#<##{self.class.name} #{@subject}>"
        end
      end

      class Message
        extend T::Sig

        sig { params(msg: NATS::Msg).void }
        def initialize(msg)
          @msg = msg
        end

        sig { returns(T.untyped) }
        def data
          @data ||= T.let(MessagePack.unpack(@msg.data), T.untyped)
        end

        sig { params(args: T.untyped).void }
        def respond(*args)
          @msg.respond(T.unsafe(MessagePack).pack(*args))
        end
      end

      extend T::Sig

      UUIDv4 =
        /
        \A
          [[:xdigit:]]{8}
          -
          [[:xdigit:]]{4}
          -
          4
          [[:xdigit:]]{3}
          -
          [89ab]
          [[:xdigit:]]{3}
          -
          [[:xdigit:]]{12}
        \Z
      /x

      CALLBACK_HANDLER_ID = /\A[[:xdigit:]]{64}\Z/ # hex-encoded sha256
      SESSION_TOKEN_LENGTH = 32
      SESSION_TOKEN = /\A[[:alnum:]]{#{SESSION_TOKEN_LENGTH}}\Z/

      sig { returns(String) }
      def generate_session_token
        # (26 + 26 + 10) ** 32 should be more than enough bits for an eternity.
        SecureRandom.alphanumeric(SESSION_TOKEN_LENGTH)
      end

      sig { returns(Symbol) }
      attr_reader :type
      sig { returns(String) }
      attr_reader :app_name
      sig { returns(String) }
      attr_reader :region
      sig { returns(String) }
      attr_reader :alloc_id
      sig { returns(NATS::Client) }
      attr_reader :nats
      sig { returns(T.untyped) }
      attr_reader :logger

      sig { params(type: Symbol).void }
      def initialize(type)
        @type = type
        @app_name = T.let(ENV.fetch("FLY_APP_NAME"), String)
        @region = T.let(ENV.fetch("FLY_REGION"), String)
        @alloc_id = T.let(ENV.fetch("FLY_ALLOC_ID"), String)

        @logger =
          T.let(
            Console.logger.with(name: "#{type}.#{region}.#{alloc_id}"),
            T.untyped
          )

        @nats = T.let(NATS::IO::Client.new, NATS::Client)

        @nats.on_disconnect { logger.warn("NATS", "disconnected") }
        @nats.on_reconnect { logger.warn("NATS", "reconnected") }

        nats_server = ENV.fetch("NATS_SERVER").gsub("FLY_REGION", @region)
        @logger.warn("NATS") { "Connecting to #{nats_server.inspect}" }

        @nats.connect(
          servers: [nats_server],
          reconnect: true,
          reconnect_time_wait: 1,
          max_reconnect_attempts: -1
        )

        @logger.info("NATS", "Connected")
      end

      sig { returns(String) }
      def inspect
        "#<#{self.class.name} #{type}.#{region}.#{alloc_id}>"
      end

      sig { params(session_id: String).returns(String) }
      def session_cookie_name(session_id)
        "mayu-session-#{session_id}"
      end

      sig { params(session_id: String, token: String).returns(Subject) }
      def session(session_id, token)
        Subject.new(
          @nats,
          build_subject(:session, session_hash(session_id, token))
        )
      end

      sig { params(connection_id: String).returns(Subject) }
      def connection(connection_id)
        Subject.new(@nats, build_subject(:connection, connection_id))
      end

      sig { returns(Subject) }
      def workers
        Subject.new(@nats, build_subject(:workers))
      end

      private

      sig { params(session_id: String, token: String).returns(String) }
      def session_hash(session_id, token)
        Digest::SHA256.hexdigest(
          Digest::SHA256.digest(session_id.to_s) +
            Digest::SHA256.digest(token.to_s)
        )
      end

      sig do
        params(
          type: T.any(Symbol, String, Integer),
          rest: T.any(Symbol, String, Integer)
        ).returns(String)
      end
      def build_subject(type, *rest)
        [:mayu, type, *rest].join(".")
      end
    end
  end
end
