#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "async"
require "delegate"
require_relative "event_stream"
require_relative "../session"

class Mayu::Server::EventStreamTest < Minitest::Test
  Writer = Mayu::Server::EventStream::Writer

  Request = Data.define(:body)

  class Counter
    attr_reader :value

    def initialize
      @value = 0
    end

    def increment(by: 1, **)
      @value += by
    end
  end

  Metrics =
    Data.define(
      :command_batches_total,
      :command_batch_commands_total,
      :command_batch_uncompressed_bytes_total,
      :command_batch_compressed_bytes_total
    )

  def test_reads_the_client_ping_frame_fixture
    request =
      Request.new(
        [
          [
            0x00,
            0x00,
            0x00,
            0x00,
            0x09,
            0x94,
            0xa4,
            0x50,
            0x69,
            0x6e,
            0x67,
            0x7b,
            0xc0,
            0xc0
          ].pack("C*")
        ]
      )

    messages = []
    Mayu::Server::EventStream.each_incoming_message(request) do |message|
      messages << message
    end

    assert_equal([["Ping", 123, nil, nil]], messages)
    assert_equal(
      Mayu::Session::Events::PingEvent[123],
      Mayu::Session::Events.parse(messages.first)
    )
  end

  def test_reads_every_message_from_a_single_chunk
    messages = []
    request = Request.new([pack_messages(["Ping", 1], ["Ping", 2])])

    Mayu::Server::EventStream.each_incoming_message(request) do |message|
      messages << message
    end

    assert_equal([["Ping", 1], ["Ping", 2]], messages)
  end

  def test_reads_a_message_split_across_chunks
    messages = []
    packed = pack_messages(["Ping", 1])
    request = Request.new([packed.byteslice(0, 2), packed.byteslice(2..)])

    Mayu::Server::EventStream.each_incoming_message(request) do |message|
      messages << message
    end

    assert_equal([["Ping", 1]], messages)
  end

  def test_rejects_incomplete_messages
    packed = pack_messages(["Ping", 1])
    request = Request.new([packed.byteslice(0...-1)])

    assert_raises(Mayu::Server::EventStream::InvalidMessageError) do
      Mayu::Server::EventStream.each_incoming_message(request) { flunk }
    end
  end

  def test_rejects_oversized_messages
    request = Request.new([pack_messages(["Ping", 1])])

    assert_raises(Mayu::Server::EventStream::MessageTooLargeError) do
      Mayu::Server::EventStream.each_incoming_message(
        request,
        max_message_bytes: 4
      ) { flunk }
    end
  end

  def test_decompresses_independently_framed_messages
    event = ["Callback", "listener", {target: {value: "Mayu" * 100}}, 1]
    request = Request.new([pack_compressed_message(event)])
    messages = []

    Mayu::Server::EventStream.each_incoming_message(request) do |message|
      messages << message
    end

    assert_equal([event], messages)
  end

  def test_rejects_messages_that_expand_past_the_decompressed_limit
    event = ["Callback", "listener", {target: {value: "Mayu" * 100}}, 1]
    request = Request.new([pack_compressed_message(event)])

    assert_raises(Mayu::Server::EventStream::MessageTooLargeError) do
      Mayu::Server::EventStream.each_incoming_message(
        request,
        max_decompressed_message_bytes: 32
      ) { flunk }
    end
  end

  def test_rejects_invalid_compressed_messages
    request = Request.new([frame(1, "not deflate")])

    assert_raises(Mayu::Server::EventStream::InvalidMessageError) do
      Mayu::Server::EventStream.each_incoming_message(request) { flunk }
    end
  end

  def test_rejects_unknown_frame_encodings
    request = Request.new([frame(2, MessagePack.pack(["Ping", 1]))])

    assert_raises(Mayu::Server::EventStream::InvalidMessageError) do
      Mayu::Server::EventStream.each_incoming_message(request) { flunk }
    end
  end

  def test_finishing_preserves_unread_transfer_and_compression_trailer
    writer = Writer.new
    writer.write_batch(
      Mayu::Runtime::Batch[[Mayu::Runtime::Commands::Initialize[{}]]],
      seq: 1
    )
    writer.write_batch(
      Mayu::Runtime::Batch[
        [Mayu::Runtime::Commands::Transfer["encrypted state"]]
      ],
      seq: 2
    )
    writer.close_write
    writer.close_write

    bytes = +""
    while (chunk = writer.read)
      bytes << chunk
    end
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    frames = Mayu::Server::EventStream.command_frames(inflater.inflate(bytes))
    assert(inflater.finished?)
    assert_equal(
      [
        [1, [["Initialize", {}]]],
        [2, [["Transfer", "encrypted state"]]]
      ],
      frames.map { MessagePack.unpack(it) }
    )
    writer.close
    assert(writer.wait)
  ensure
    writer&.close
    inflater&.close
  end

  def test_a_command_frame_is_its_length_and_then_the_batch
    writer = Writer.new(compress: false)
    writer.write_batch(
      Mayu::Runtime::Batch[[Mayu::Runtime::Commands::Pong[1]]],
      seq: 7
    )
    writer.close_write

    # [7, [["Pong", 1]]] is 92 07 91 92 a4 "Pong" 01: ten bytes.
    assert_equal(
      [0, 0, 0, 10, 0x92, 0x07, 0x91, 0x92, 0xa4, 0x50, 0x6f, 0x6e, 0x67, 0x01],
      writer.read.bytes
    )
  ensure
    writer&.close
  end

  def test_a_cut_off_command_frame_is_rejected
    frame = Mayu::Server::EventStream.command_frame(MessagePack.pack([["Pong", 1]]))

    [frame[0, 2], frame[0, frame.bytesize - 1]].each do |bytes|
      assert_raises(Mayu::Server::EventStream::InvalidMessageError) do
        Mayu::Server::EventStream.command_frames(bytes)
      end
    end
  end

  def test_records_command_batch_counts_and_stream_bytes
    metrics = Metrics.new(Counter.new, Counter.new, Counter.new, Counter.new)
    writer = Writer.new(metrics:)
    batch =
      Mayu::Runtime::Batch[
        [
          Mayu::Runtime::Commands::Initialize[{}],
          Mayu::Runtime::Commands::Transfer["state"]
        ]
      ]

    writer.write_batch(batch, seq: 1)

    assert_equal(1, metrics.command_batches_total.value)
    assert_equal(2, metrics.command_batch_commands_total.value)
    assert_operator(metrics.command_batch_uncompressed_bytes_total.value, :>, 0)
    assert_operator(metrics.command_batch_compressed_bytes_total.value, :>, 0)
  ensure
    writer&.close
  end

  def test_counts_raw_messagepack_as_sent_bytes_when_compression_is_disabled
    metrics = Metrics.new(Counter.new, Counter.new, Counter.new, Counter.new)
    writer = Writer.new(compress: false, metrics:)
    batch = Mayu::Runtime::Batch[[Mayu::Runtime::Commands::Transfer["state"]]]

    2.times { writer.write_batch(batch, seq: 1) }
    writer.close_write

    chunks = [writer.read, writer.read]
    assert_equal(
      [[1, [["Transfer", "state"]]]] * 2,
      Mayu::Server::EventStream.command_frames(chunks.join).map { MessagePack.unpack(it) }
    )
    assert_nil(writer.read)
    bytes = chunks.sum(&:bytesize)
    assert_equal(bytes, metrics.command_batch_uncompressed_bytes_total.value)
    assert_equal(bytes, metrics.command_batch_compressed_bytes_total.value)
    writer.close
    assert(writer.wait)
  ensure
    writer&.close
  end

  def test_wait_after_consumer_disconnect_is_not_lost
    writer = Writer.new
    batch =
      Mayu::Runtime::Batch[[Mayu::Runtime::Commands::Transfer["state"]]]
    writer.write_batch(batch, seq: 1)
    writer.close
    writer.close
    refute(writer.wait)
    assert_nil(writer.read)
    assert_raises(Mayu::Server::EventStream::ClosedStreamError) do
      writer.write_batch(batch, seq: 1)
    end
  end

  def test_completion_includes_the_consumers_final_protocol_writes
    Async do |task|
      writer = Writer.new
      finished = false
      consumer = task.async do
        writer.read until writer.empty?
        writer.close
        sleep 0.02
        finished = true
      end
      writer.write_batch(
        Mayu::Runtime::Batch[[Mayu::Runtime::Commands::Transfer["state"]]],
        seq: 1
      )
      writer.close_write
      assert(writer.wait_finished)
      assert(finished)
      consumer.wait
    end.wait
  end

  class InterruptedDeflater < SimpleDelegator
    def deflate(input, flush)
      @output = super
      raise Zlib::BufError, "completed flush interrupted by a signal"
    end

    def flush_next_out
      @output
    end
  end

  def test_signal_interrupted_flush_preserves_bytes_without_replaying_input
    writer = Writer.new
    compressor = writer.instance_variable_get(:@deflate)
    writer.instance_variable_set(:@deflate, InterruptedDeflater.new(compressor))
    writer.write_batch(
      Mayu::Runtime::Batch[[Mayu::Runtime::Commands::Transfer["state"]]],
      seq: 1
    )
    writer.close_write
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    bytes = writer.read + writer.read
    assert_equal(
      [[1, [["Transfer", "state"]]]],
      Mayu::Server::EventStream.command_frames(inflater.inflate(bytes)).map { MessagePack.unpack(it) }
    )
    assert(inflater.finished?)
  ensure
    writer&.close
    inflater&.close
  end

  private

  def pack_messages(*messages)
    messages.map { frame(0, MessagePack.pack(it)) }.join
  end

  def pack_compressed_message(message)
    deflater = Zlib::Deflate.new(nil, -Zlib::MAX_WBITS)
    compressed = deflater.deflate(MessagePack.pack(message), Zlib::FINISH)
    frame(1, compressed)
  ensure
    deflater&.close
  end

  def frame(encoding, payload)
    [encoding, payload.bytesize].pack("CN") + payload
  end
end
