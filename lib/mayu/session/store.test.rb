#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "async"
require "async/barrier"
require "async/semaphore"
require_relative "store"

class Mayu::Session::StoreTest < Minitest::Test
  class Session
    attr_reader :id, :outcome

    def initialize(id, behavior)
      @id, @behavior = id, behavior
    end

    def running? = @behavior != :disconnected

    def transfer!
      case @behavior
      when :error then raise TypeError, "cannot serialize"
      when :timeout then sleep 10
      end
      @outcome = :queued
    end

    def transfer_failed! = @outcome = :failed
    def stop = @outcome = :stopped
  end

  def test_failures_do_not_block_other_transfers_or_disconnected_sessions
    Async do |task|
      store = Mayu::Session::Store.new(metrics: nil)
      sessions = [:error, :timeout, :disconnected, :ok, :ok].each_with_index.map { |behavior, id| Session.new(id, behavior) }
      sessions.each { |session| store.store(session) }
      task.with_timeout(2) { store.transfer_all }
      assert_equal([:failed, :failed, :stopped, :queued, :queued], sessions.map(&:outcome))
      store.transfer_all
    end.wait
  end
end
