#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require_relative "shutdown_signal"

class Mayu::Server::ShutdownSignalTest < Minitest::Test
  def test_closing_one_registration_preserves_other_signal_consumers
    received = []
    handlers = Async::Signals::Handlers.new
    handlers.trap(:TERM) { |signal| received << signal }

    Async::Signals.install(handlers) do
      Mayu::Server::ShutdownSignal.open do |shutdown|
        Async::Signals.controller.dispatch("TERM")
        assert(shutdown.requested?)
        shutdown.wait
        Async::Signals.controller.dispatch("INT")
        shutdown.wait
      end

      Async::Signals.controller.dispatch("TERM")
      assert_equal([Signal.list.fetch("TERM")] * 2, received)
    end
  end

  def test_previous_traps_are_restored_even_when_the_scope_raises
    previous = {}
    handler = proc {}
    [:INT, :TERM].each { |name| previous[name] = Signal.trap(name, handler) }

    assert_raises(RuntimeError) do
      Mayu::Server::ShutdownSignal.open { raise "startup failed" }
    end

    [:INT, :TERM].each do |name|
      assert_same(handler, Signal.trap(name, handler))
    end
  ensure
    previous.each { |name, trap| Signal.trap(name, trap) }
  end
end
