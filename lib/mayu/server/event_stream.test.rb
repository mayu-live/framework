#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "async"
require "delegate"
require_relative "event_stream"

class Mayu::Server::EventStreamTest < Minitest::Test
  Writer = Mayu::Server::EventStream::Writer

  def test_finishing_preserves_unread_transfer_and_compression_trailer
    writer = Writer.new
    writer.write(["Initialize", {}])
    writer.write(["Transfer", "encrypted state"])
    writer.close_write
    writer.close_write

    bytes = +""
    while (chunk = writer.read)
      bytes << chunk
    end
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    unpacker = MessagePack::Unpacker.new
    unpacker.feed(inflater.inflate(bytes))
    assert(inflater.finished?)
    assert_equal([["Initialize", {}], ["Transfer", "encrypted state"]], unpacker.each.to_a)
    writer.close
    assert(writer.wait)
  ensure
    writer&.close
    inflater&.close
  end

  def test_wait_after_consumer_disconnect_is_not_lost
    writer = Writer.new
    writer.write(["Transfer", "state"])
    writer.close
    writer.close
    refute(writer.wait)
    assert_nil(writer.read)
    assert_raises(Mayu::Server::EventStream::ClosedStreamError) { writer.write(["late"]) }
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
      writer.write(["Transfer", "state"])
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
    writer.write(["Transfer", "state"])
    writer.close_write
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    bytes = writer.read + writer.read
    assert_equal(["Transfer", "state"], MessagePack.unpack(inflater.inflate(bytes)))
    assert(inflater.finished?)
  ensure
    writer&.close
    inflater&.close
  end
end
