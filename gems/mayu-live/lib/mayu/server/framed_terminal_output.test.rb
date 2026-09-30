#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require_relative "framed_terminal_output"

class Mayu::Server::FramedTerminalOutputTest < Minitest::Test
  def test_the_body_is_behind_a_bar
    output = log(:info, "Update #2 completed", "changed files:", format: Console::Terminal::Text)
    lines = output.lines

    assert_includes(lines[0], "Update #2 completed")
    assert_match(/\A +│ changed files:\n\z/, lines[1])
    assert_equal(2, lines.size)
  end

  def test_the_bar_takes_the_severity_colour
    info = log(:info, "subject", "body", format: Console::Terminal::XTerm)
    error = log(:error, "subject", "body", format: Console::Terminal::XTerm)

    assert_match(/\e\[32m│\e\[0m body/, info, "expected a green bar")
    assert_match(/\e\[31m│\e\[0m body/, error, "expected a red bar")
  end

  private

  def log(severity, subject, *arguments, format:)
    stream = StringIO.new
    stream.define_singleton_method(:winsize) { [24, 120] }
    terminal = Mayu::Server::FramedTerminalOutput.new(stream, format:)
    Console::Logger.new(terminal).public_send(severity, subject, *arguments)
    stream.string
  end
end
