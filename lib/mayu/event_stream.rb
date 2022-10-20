# typed: strict
# frozen_string_literal: true

require "nanoid"
require "msgpack"

module Mayu
  module EventStream
    class Blob
      extend T::Sig

      sig { params(data: String).void }
      def initialize(data)
        @data = data
      end

      sig { params(data: String).returns(T.attached_class) }
      def self.from_msgpack_ext(data)
        new(data)
      end

      sig { returns(String) }
      def to_msgpack_ext
        @data
      end
    end

    class Wrapper < MessagePack::Factory
      extend T::Sig

      sig { void }
      def initialize
        super()

        self.register_type(0x01, Blob)
      end
    end

    class Message
      extend T::Sig

      sig { returns(String) }
      attr_reader :id
      sig { returns(String) }
      attr_reader :event
      sig { returns(T.untyped) }
      attr_reader :data

      sig { params(event: T.any(String, Symbol), data: T.untyped).void }
      def initialize(event, data = {})
        @id = T.let(Nanoid.generate, String)
        @event = T.let(event.to_s, String)
        @data = data
        @wrapper = T.let(Wrapper.new, Wrapper)
      end

      sig { returns(String) }
      def to_s = pack

      sig { returns(String) }
      def pack
        Zlib.deflate(@wrapper.pack([@id, @event, @data]))
      end
    end

    class Log
      extend T::Sig

      sig { void }
      def initialize
        @log = T.let([], T::Array[Message])
        @queue = T.let(Async::Queue.new, Async::Queue)
      end

      sig { returns(T::Boolean) }
      def empty?
        @queue.empty?
      end

      sig { params(event: Symbol, data: T.untyped).void }
      def push(event, data = {})
        @queue.enqueue(Message.new(event, data))
      end

      sig { params(id: String).void }
      def ack(id)
        if index = @log.map(&:id).index(id)
          @log.slice!(0..index)
        end
      end

      sig { params(last_id: String).returns(T::Array[Message]) }
      def replay(last_id)
        ack(last_id)
        @log.dup
      end

      sig { returns(Message) }
      def pop
        event = @queue.dequeue
        # There is no ack-functionality in the client so this will just grow anyways..
        # @log.push(event)
        event
      end
    end

    class Stream
    end
  end
end
