#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "stringio"
require "uri"
require "console"
require "console/output/terminal"

require_relative "listen_event_formatter"

class Mayu::Server::ListenEventTest < Minitest::Test
  URL = "https://localhost:9292"

  def test_log_files_get_one_plain_line
    output = StringIO.new
    event = Mayu::Server::ListenEvent.new(:server, url: URI.parse(URL))
    Console::Logger.new(Console::Output::Text.new(output)).info("server", event:)

    assert_includes(output.string, "Starting server on #{URL}")
    refute_match(/\e\[/, output.string, "expected no escape codes in text output")
  end

  def test_terminals_get_the_address_in_bold_blue
    output = StringIO.new
    output.define_singleton_method(:winsize) { [24, 120] }
    terminal = Console::Output::Terminal.new(output, format: Console::Terminal::XTerm)
    event = Mayu::Server::ListenEvent.new(:metrics, url: "http://localhost:9091")
    Console::Logger.new(terminal).info("metrics", event:)

    assert_match(/\e\[[\d;]*34[\d;]*mhttp:\/\/localhost:9091/, output.string, "expected the url in blue")
    assert_includes(output.string, "Starting metrics server on")
  end

  def test_the_collector_line_stays_plain_on_terminals
    output = StringIO.new
    output.define_singleton_method(:winsize) { [24, 120] }
    terminal = Console::Output::Terminal.new(output, format: Console::Terminal::XTerm)
    event = Mayu::Server::ListenEvent.new(:collector, url: "/tmp/metrics.ipc")
    Console::Logger.new(terminal).info("collector", event:)

    assert_includes(output.string, "| Starting metrics collection on /tmp/metrics.ipc")
  end

  def test_hash_is_serializable
    hash = JSON.parse(JSON.generate(Mayu::Server::ListenEvent.new(:collector, url: "/tmp/metrics.ipc").to_hash))

    assert_equal({"type" => "mayu.listen", "service" => "collector", "url" => "/tmp/metrics.ipc"}, hash)
  end

  def test_unknown_services_are_rejected
    assert_raises(ArgumentError) { Mayu::Server::ListenEvent.new(:teapot, url: URL) }
  end
end
