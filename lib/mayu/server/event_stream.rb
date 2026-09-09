# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "msgpack"
require "zlib"
require "async/http/body/writable"
require "async/promise"

module Mayu
  class Server
    module EventStream
      CONTENT_TYPE = "application/vnd.mayu.event-stream"
      CONTENT_ENCODING = "deflate-raw"

      class ClosedStreamError < StandardError
      end

      class MsgPackWrapper < MessagePack::Factory
        def initialize
          super

          register_type(0x01, Blob)
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
          @on_close = Async::Promise.new
          @write_closed = false
          @consumer_closed = false
        end

        def wait
          @on_close.wait
        end

        def read
          @consumer_task ||= Async::Task.current?
          super
        end

        def wait_finished
          flushed = wait
          # Body#close is called just before HTTP sends END_STREAM. Joining the
          # consumer also waits for those final protocol writes.
          @consumer_task.wait if @consumer_task && !@consumer_task.current?
          flushed
        end

        def write(patch)
          if @write_closed || @consumer_closed
            raise ClosedStreamError,
              "Attempted to write to a closed #{self.class.name}"
          end

          patch
            .then { Array(it) }
            .then { @wrapper.pack(it) }
            .then { deflate_chunk(it) }
            .then { super(it) }
        end

        def close_write(reason = nil)
          return if @write_closed || @consumer_closed
          @write_closed = true
          @queue.push(@deflate.finish) unless reason
          @deflate.close
          super
        end

        def close(reason = nil)
          return if @consumer_closed
          flushed = @write_closed && @queue.empty? && reason.nil?
          @consumer_closed = true
          @deflate.close unless @deflate.closed?
          super
          @on_close.resolve(flushed)
        end

        private

        def deflate_chunk(input)
          expected_total = @deflate.total_in + input.bytesize
          @deflate.deflate(input, Zlib::SYNC_FLUSH)
        rescue Zlib::BufError
          # A signal can interrupt Ruby's native zlib call after SYNC_FLUSH
          # completed and cause a retry with no input left. Recover only a
          # complete flush whose input was fully consumed; never replay input.
          raise unless @deflate.total_in == expected_total && @deflate.avail_in.zero?
          output = @deflate.flush_next_out
          raise unless output.end_with?("\x00\x00\xff\xff".b)
          output
        end
      end

      Blob =
        Data.define(:data) do
          def self.from_msgpack_ext(data) = new(data)
          def to_msgpack_ext = data
        end

      def self.each_incoming_message(request)
        buf = +""

        request.body.each do |chunk|
          buf += chunk

          if (idx = buf.index("\n"))
            yield JSON.parse(buf[0..idx], symbolize_names: true)
            buf = buf[idx.succ..].to_s
          end
        end
      end
    end
  end
end
