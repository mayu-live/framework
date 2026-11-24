#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "minitest/autorun"
require "async"
require "async/http/protocol"
require "msgpack"

require_relative "app"
require_relative "../session"
require "mayu/build"
require "mayu/test"

# How a command stream opens for a real session: with the ids, with the
# batches the browser missed, or with the whole page.
class Mayu::Server::SessionStreamTest < Minitest::Test
  Commands = Mayu::Runtime::Commands

  class Environment
    attr_reader :config, :metrics, :marshaller
    attr_accessor :module_provider, :inspector

    def initialize
      server =
        Mayu::Configuration::ServerConfig.parse(
          {"command_stream_compression" => false}
        )
      @config = Struct.new(:server).new(server)
      @metrics = Mayu::Test::FakeMetrics.new
    end

    def runtime_init_js_path = "/.mayu/runtime/init-testhash.js"

    def development? = false
  end

  def with_app
    Async do |task|
      environment = Environment.new
      app = Mayu::Server::App.allocate
      app.instance_variable_set(:@environment, environment)
      app.instance_variable_set(:@body_barrier, Async::Barrier.new(parent: task))
      app.instance_variable_set(:@streams, {})
      cookies = Object.new
      cookies.define_singleton_method(:set_token_cookie_header) { |_session| {} }
      app.instance_variable_set(:@cookies, cookies)

      session =
        Mayu::Session.new(
          environment:,
          request_info: Mayu::Session::RequestInfo.new(path: "/missing", headers: {}, http2: false)
        )

      yield app, session, task
    ensure
      app&.instance_variable_get(:@streams)&.each_value { it.body.close }
      app&.instance_variable_get(:@body_barrier)&.stop
    end.wait
  end

  def open_stream(app, session, after: nil)
    response = app.send(:run_session_stream, Struct.new(:headers).new({}), session, after:)
    assert_equal(200, response.status)
    response.body
  end

  # The next batch on the stream, as [seq, command names].
  def read_batch(task, body)
    chunk = task.with_timeout(1) { body.read }
    frames = Mayu::Server::EventStream.command_frames(chunk)
    assert_equal(1, frames.size)
    seq, commands = MessagePack.unpack(frames.first, allow_unknown_ext: true)
    [seq, commands.map(&:first), commands]
  end

  def wait_until_running(task, session)
    task.with_timeout(1) { task.sleep(0) until session.running? }
  end

  def test_a_first_stream_starts_with_the_ids
    with_app do |app, session, task|
      body = open_stream(app, session)

      seq, names = read_batch(task, body)

      assert_equal(1, seq)
      assert_equal("Initialize", names.first)
    end
  end

  def test_batches_are_numbered_in_the_order_they_are_sent
    with_app do |app, session, task|
      body = open_stream(app, session)
      read_batch(task, body)
      wait_until_running(task, session)

      session.receive_message(["Ping", 11, 1, nil])
      session.receive_message(["Ping", 12, 1, nil])

      first = read_batch(task, body)
      second = read_batch(task, body)
      assert_equal([2, ["Pong"]], first.first(2))
      assert_equal([3, ["Pong"]], second.first(2))
      assert_equal([11, 12], [first, second].map { it.last.first.last })
    end
  end

  def test_a_reconnecting_browser_is_sent_only_what_it_missed
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      wait_until_running(task, session)
      session.receive_message(["Ping", 11, 1, nil])
      assert_equal(2, read_batch(task, first).first)

      # The browser lost the stream having applied only the first batch.
      first.close
      task.with_timeout(1) { task.sleep(0) while session.running? }

      second = open_stream(app, session, after: 1)

      seq, names, commands = read_batch(task, second)
      assert_equal(2, seq)
      assert_equal(["Pong"], names)
      assert_equal(11, commands.first.last)
    end
  end

  def test_a_batch_taken_as_the_stream_closed_is_not_lost
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      wait_until_running(task, session)

      # The stream goes away with a batch already on its way out.
      first.close
      session.instance_variable_get(:@engine).enqueue_command(Commands::Pong[99])
      task.with_timeout(1) { task.sleep(0) while session.running? }

      second = open_stream(app, session, after: 1)

      seq, names, commands = read_batch(task, second)
      assert_equal(2, seq)
      assert_equal(["Pong"], names)
      assert_equal(99, commands.first.last)
    end
  end

  def test_a_browser_that_is_up_to_date_is_sent_nothing_until_something_changes
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      first.close
      task.with_timeout(1) { task.sleep(0) while session.running? }

      second = open_stream(app, session, after: 1)
      wait_until_running(task, session)
      session.receive_message(["Ping", 21, 1, nil])

      assert_equal([2, ["Pong"]], read_batch(task, second).first(2))
    end
  end

  def test_a_browser_that_can_not_be_caught_up_is_sent_the_page
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      first.close
      task.with_timeout(1) { task.sleep(0) while session.running? }

      # It names a batch this session never sent.
      second = open_stream(app, session, after: 40)

      seq, names, commands = read_batch(task, second)
      assert_equal(2, seq)
      assert_equal("Resync", names.first)
      assert_includes(commands.first[1], "<!DOCTYPE html>")
      assert_equal(
        MessagePack.unpack(MessagePack.pack(session.dom_id_tree)),
        commands.first[2]
      )
    end
  end

  def test_an_acknowledged_batch_can_not_be_replayed_so_the_page_is_sent
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      wait_until_running(task, session)
      session.receive_message(["Ping", 11, 1, nil])
      read_batch(task, first)
      session.receive_message(["Ping", 12, 2, nil])
      read_batch(task, first)
      first.close
      task.with_timeout(1) { task.sleep(0) while session.running? }

      second = open_stream(app, session, after: 1)

      assert_equal("Resync", read_batch(task, second)[1].first)
    end
  end

  # The batches of the first stream changed the page on this side. A browser
  # that lost that stream before applying any of them still has the page it
  # loaded, which the ids alone would not bring up to date.
  def test_a_browser_that_names_no_batch_after_some_were_sent_is_sent_the_page
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      wait_until_running(task, session)
      first.close
      task.with_timeout(1) { task.sleep(0) while session.running? }

      second = open_stream(app, session)

      assert_equal("Resync", read_batch(task, second)[1].first)
    end
  end

  # A transfer that is posted twice restores the session twice, under one id.
  def test_a_stream_for_another_copy_of_the_session_stops_the_first_copy
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      wait_until_running(task, session)

      copy =
        Mayu::Session.new(
          environment: app.instance_variable_get(:@environment),
          request_info: Mayu::Session::RequestInfo.new(path: "/missing", headers: {}, http2: false)
        )
      id = session.id
      copy.define_singleton_method(:id) { id }

      second = open_stream(app, copy)

      assert(first.closed?)
      refute(session.running?)
      assert_equal("Initialize", read_batch(task, second)[1].first)
      wait_until_running(task, copy)
      assert_equal(1, app.stream_count)
    ensure
      copy&.stop
    end
  end

  def test_a_second_stream_takes_over_from_one_that_is_still_open
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      wait_until_running(task, session)

      second = open_stream(app, session, after: 1)

      assert(first.closed?)
      wait_until_running(task, session)
      assert_equal(1, app.stream_count)

      session.receive_message(["Ping", 31, 1, nil])
      seq, names, commands = read_batch(task, second)
      assert_equal([2, ["Pong"]], [seq, names])
      assert_equal(31, commands.first.last)

      # The first stream winding down does not stop the session again.
      task.sleep(0.05)
      assert(session.running?)
      assert_equal(1, app.stream_count)
    end
  end

  def test_streams_that_take_over_in_quick_succession_leave_one_running
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      wait_until_running(task, session)

      # Nothing gets to run between these two.
      second = open_stream(app, session, after: 999)
      third = open_stream(app, session, after: 1)

      assert(first.closed?)
      assert(second.closed?)
      wait_until_running(task, session)
      task.sleep(0.05)
      assert(session.running?)
      assert_equal(1, app.stream_count)
      refute(third.closed?)

      # The second stream opened with the page, so the third could not be
      # caught up batch by batch and got the page as well.
      assert_equal("Resync", read_batch(task, third)[1].first)
      session.receive_message(["Ping", 41, nil, nil])
      assert_equal(["Pong"], read_batch(task, third)[1])
    end
  end

  def test_two_streams_that_take_over_at_the_same_time_leave_one_running
    with_app do |app, session, task|
      first = open_stream(app, session)
      read_batch(task, first)
      wait_until_running(task, session)

      # Both find the first stream open and wait for it to wind down.
      openings =
        [999, 1].map do |after|
          task.async { open_stream(app, session, after:) }
        end
      bodies = openings.map(&:wait)

      wait_until_running(task, session)
      task.sleep(0.05)
      assert(session.running?)
      assert_equal(1, app.stream_count)
      assert_equal(1, bodies.count { !it.closed? })

      open = bodies.find { !it.closed? }
      read_batch(task, open)
      session.receive_message(["Ping", 51, nil, nil])
      assert_equal(["Pong"], read_batch(task, open)[1])
    end
  end

  def test_the_last_batch_header_is_read_as_a_number
    app = Mayu::Server::App.allocate
    request = ->(value) { Struct.new(:headers).new({"mayu-last-batch" => value}) }

    assert_nil(app.send(:last_batch, request.call(nil)))
    assert_equal(12, app.send(:last_batch, request.call(["12"])))
    assert_equal(0, app.send(:last_batch, request.call(["0"])))
    assert_equal(-1, app.send(:last_batch, request.call(["twelve"])))
    assert_equal(-1, app.send(:last_batch, request.call(["-3"])))
    assert_equal(-1, app.send(:last_batch, request.call(["1", "2"])))
  end
end
