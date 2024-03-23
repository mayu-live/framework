# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "msgpack"
require "zlib"
require "async/notification"

module Mayu
  class Server
    module EventStream
      CONTENT_TYPE = "application/vnd.mayu.event-stream"
      CONTENT_ENCODING = "deflate-raw"

      class MsgPackWrapper < MessagePack::Factory
        def initialize
          super()

          self.register_type(0x01, Blob)
        end
      end

      class Writer < Async::HTTP::Body::Writable
        def initialize(...)
          super
          @deflate =
            Zlib::Deflate.new(
              Zlib::BEST_COMPRESSION,
              -Zlib::MAX_WBITS,
              Zlib::MAX_MEM_LEVEL,
              Zlib::HUFFMAN_ONLY
            )
          @wrapper = MsgPackWrapper.new
          @on_close = Async::Notification.new
        end

        def wait
          @on_close.wait
        end

        def write(buf)
          if @closed
            puts "Attempting to write #{buf.inspect} to closed #{self.class.name}"
            return
          end

          buf
            .then { PatchSet[_1].to_a }
            .then { @wrapper.pack(_1) }
            .then { @deflate.deflate(_1, Zlib::SYNC_FLUSH) }
            .then { super(_1) }
        end

        def close(reason = nil)
          @on_close.signal(reason)

          begin
            @queue.enqueue(@deflate.flush(Zlib::FINISH))
          rescue StandardError
            nil
          end
          begin
            @deflate.close
          rescue StandardError
            nil
          end
          super
        end
      end

      Blob =
        Data.define(:data) do
          def self.from_msgpack_ext(data) = new(data)
          def to_msgpack_ext = data
        end

      PatchSet =
        Data.define(:id, :patches) do
          def self.[](patches) = new(SecureRandom.alphanumeric, [patches].flatten)

          def to_a
            patches.map do |patch|
              [patch.class.name[/[^:]+\z/], *patch.deconstruct]
            end
          end
        end

      def self.each_incoming_message(request)
        buf = String.new

        request.body.each do |chunk|
          buf += chunk

          if idx = buf.index("\n")
            yield JSON.parse(buf[0..idx], symbolize_names: true)
            buf = buf[idx.succ..-1].to_s
          end
        end
      end
    end
  end
end
