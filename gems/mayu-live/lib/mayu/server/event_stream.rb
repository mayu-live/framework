# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "msgpack"
require "zlib"
require "async/http/body/writable"
require "async/promise"

require_relative "../runtime/commands"

module Mayu
  class Server
    module EventStream
      CONTENT_TYPE = "application/vnd.mayu.event-stream"
      CONTENT_ENCODING = "deflate-raw"
      CLIENT_EVENT_FRAME_HEADER_BYTES = 5
      CLIENT_EVENT_ENCODING_RAW = 0
      CLIENT_EVENT_ENCODING_DEFLATE_RAW = 1
      MAX_INCOMING_MESSAGE_BYTES = 1024 * 1024

      class ClosedStreamError < StandardError
      end

      class InvalidMessageError < StandardError
      end

      class MessageTooLargeError < StandardError
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

        def write_batch(batch)
          unless batch.is_a?(Runtime::Batch)
            raise ArgumentError, "Expected #{Runtime::Batch}, got #{batch.class}"
          end
          batch.validate!

          if @write_closed || @consumer_closed
            raise ClosedStreamError,
              "Attempted to write to a closed #{self.class.name}"
          end

          batch
            .then { @wrapper.pack(it) }
            .then { deflate_chunk(it) }
            .then { write(it) }
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

      def self.each_incoming_message(
        request,
        max_message_bytes: MAX_INCOMING_MESSAGE_BYTES,
        max_decompressed_message_bytes: max_message_bytes
      )
        buffer = +"".b

        request.body.each do |chunk|
          buffer << chunk

          while buffer.bytesize >= CLIENT_EVENT_FRAME_HEADER_BYTES
            encoding = buffer.getbyte(0)
            payload_bytes = buffer.unpack1("@1N")
            unless [
              CLIENT_EVENT_ENCODING_RAW,
              CLIENT_EVENT_ENCODING_DEFLATE_RAW
            ].include?(encoding)
              raise InvalidMessageError,
                "Unknown client event encoding: #{encoding}"
            end
            if payload_bytes > max_message_bytes
              raise MessageTooLargeError,
                "Incoming event exceeds #{max_message_bytes} bytes"
            end

            frame_bytes = CLIENT_EVENT_FRAME_HEADER_BYTES + payload_bytes
            break if buffer.bytesize < frame_bytes

            payload = buffer.byteslice(CLIENT_EVENT_FRAME_HEADER_BYTES, payload_bytes)
            buffer = buffer.byteslice(frame_bytes..).to_s
            packed =
              if encoding == CLIENT_EVENT_ENCODING_DEFLATE_RAW
                inflate_event(
                  payload,
                  max_bytes: max_decompressed_message_bytes
                )
              else
                payload
              end

            yield MessagePack.unpack(packed, symbolize_keys: true)
          end

          if buffer.bytesize >
              CLIENT_EVENT_FRAME_HEADER_BYTES + max_message_bytes
            raise MessageTooLargeError,
              "Incoming event exceeds #{max_message_bytes} bytes"
          end
        end

        unless buffer.empty?
          raise InvalidMessageError, "Incomplete client event frame"
        end
      rescue MessagePack::UnpackError, Zlib::Error => error
        raise InvalidMessageError, error.message
      end

      def self.inflate_event(data, max_bytes:)
        output = +"".b
        inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)

        inflater.inflate(data) do |chunk|
          if output.bytesize + chunk.bytesize > max_bytes
            raise MessageTooLargeError,
              "Decompressed event exceeds #{max_bytes} bytes"
          end

          output << chunk
        end

        unless inflater.finished? && inflater.total_in == data.bytesize
          raise InvalidMessageError, "Incomplete compressed event"
        end

        output
      ensure
        inflater&.close
      end
      private_class_method :inflate_event
    end
  end
end
