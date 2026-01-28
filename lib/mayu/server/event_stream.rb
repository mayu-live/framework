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

      class ClosedStreamError < StandardError
      end

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

        def write(patch)
          if @closed
            raise ClosedStreamError,
                  "Attempted to write to a closed #{self.class.name}"
          end

          patch
            .then { Array(_1) }
            .then { @wrapper.pack(_1) }
            .then { @deflate.deflate(_1, Zlib::SYNC_FLUSH) }
            .then { super(_1) }
        end

        def close(reason = nil)
          return if closed?

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
