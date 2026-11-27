# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
      COMMAND_FRAME_HEADER_BYTES = 4
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
        def initialize(*args, compress: true, metrics: nil, **kwargs, &block)
          super(*args, **kwargs, &block)
          @metrics = metrics
          if compress
            @deflate = Zlib::Deflate.new(
              Zlib::BEST_COMPRESSION,
              -Zlib::MAX_WBITS,
              Zlib::MAX_MEM_LEVEL,
              Zlib::HUFFMAN_ONLY
            )
          end
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

        def write_batch(batch, seq:)
          write_packed(
            EventStream.pack_batch(batch, seq),
            commands: batch.commands.size
          )
        end

        # Writes a batch that EventStream.pack_batch already packed.
        def write_packed(packed, commands:)
          if @write_closed || @consumer_closed
            raise ClosedStreamError,
              "Attempted to write to a closed #{self.class.name}"
          end

          frame = EventStream.command_frame(packed)
          payload = @deflate ? deflate_chunk(frame) : frame
          record_batch(commands, frame, payload)
          write(payload)
        end

        def close_write(reason = nil)
          return if @write_closed || @consumer_closed
          @write_closed = true
          @queue.push(@deflate.finish) if @deflate && !reason
          @deflate&.close
          super
        end

        def close(reason = nil)
          return if @consumer_closed
          flushed = @write_closed && @queue.empty? && reason.nil?
          @consumer_closed = true
          @deflate.close if @deflate && !@deflate.closed?
          super
          @on_close.resolve(flushed)
        end

        private

        def record_batch(commands, packed, payload)
          return unless @metrics

          @metrics.command_batches_total.increment
          @metrics.command_batch_commands_total.increment(by: commands)
          @metrics.command_batch_uncompressed_bytes_total.increment(
            by: packed.bytesize
          )
          @metrics.command_batch_compressed_bytes_total.increment(
            by: payload.bytesize
          )
        end

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

      # A batch as MessagePack: `[seq, commands]`. The sequence number counts
      # the batches of one session, so the browser can say which one it
      # applied last.
      def self.pack_batch(batch, seq)
        unless batch.is_a?(Runtime::Batch)
          raise ArgumentError, "Expected #{Runtime::Batch}, got #{batch.class}"
        end
        batch.validate!

        packer.pack([seq, batch.commands])
      end

      def self.packer = @packer ||= MsgPackWrapper.new
      private_class_method :packer

      # A batch on the command stream is a frame: four bytes holding the
      # length of the payload, big-endian, then the batch as MessagePack. The
      # browser decodes one whole frame at a time, and a stream that ends in
      # the middle of one was cut off.
      def self.command_frame(packed)
        [packed.bytesize].pack("N") << packed
      end

      # The MessagePack payload of every frame in the bytes of a command
      # stream, after decompression.
      def self.command_frames(bytes)
        frames = []
        offset = 0

        while offset < bytes.bytesize
          header = bytes.byteslice(offset, COMMAND_FRAME_HEADER_BYTES)
          unless header.bytesize == COMMAND_FRAME_HEADER_BYTES
            raise InvalidMessageError, "Truncated command frame header"
          end

          length = header.unpack1("N")
          payload = bytes.byteslice(offset + COMMAND_FRAME_HEADER_BYTES, length)
          unless payload.bytesize == length
            raise InvalidMessageError, "Truncated command frame"
          end

          frames << payload
          offset += COMMAND_FRAME_HEADER_BYTES + length
        end

        frames
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
