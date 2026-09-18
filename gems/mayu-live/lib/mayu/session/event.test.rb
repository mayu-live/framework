#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "stringio"
require "console"
require "console/output/terminal"

require_relative "event"

class Mayu::Session::EventTest < Minitest::Test
  ID = "G9jfFMOmln9cX4yRJxqxHu7yAMA7Hzs6"

  def test_log_files_get_one_plain_line
    output = StringIO.new
    event = Mayu::Session::Event.new(:initializing, session_id: ID, path: "/demos")
    Console::Logger.new(Console::Output::Text.new(output)).info("session", event:)

    assert_includes(output.string, "Initializing session #{ID} at /demos")
    refute_match(/\e\[/, output.string, "expected no escape codes in text output")
  end

  def test_terminals_get_a_dimmed_id_and_a_coloured_verb
    text = render(Mayu::Session::Event.new(:starting, session_id: ID))

    assert_match(/\e\[[\d;]*2[\d;]*m#{ID}/o, text, "expected the id to be faint")
    assert_match(/\e\[[\d;]*32[\d;]*mStarting session/, text, "expected the verb in green")
    assert_match(/\e\[(?:\d+;)*1(?:;\d+)*mStarting session/, text, "expected a beginning to be bold")
    stopping = render(Mayu::Session::Event.new(:stopping, session_id: ID))
    refute_match(/\e\[(?:\d+;)*1(?:;\d+)*mStopping session/, stopping, "expected an ending not to be bold")
  end

  def test_each_step_has_its_own_colour
    colours =
      Mayu::Session::Event::ACTIONS.to_h do |action|
        text = render(Mayu::Session::Event.new(action, session_id: ID, path: "/"))
        [action, text[/\e\[([\d;]*)m[A-Z][a-z]+ /, 1]]
      end

    assert_equal(colours[:resuming], colours[:resuming_transferred])
    distinct = colours.except(:resuming_transferred).values
    assert_equal(distinct.uniq, distinct, "expected the other steps to differ: #{colours}")
  end

  def test_an_unflushed_stream_says_so
    finished = Mayu::Session::Event.new(:stream_finished, session_id: ID, flushed: true)
    unflushed = Mayu::Session::Event.new(:stream_finished, session_id: ID, flushed: false)

    refute_includes(render(finished), "before flushing")
    assert_includes(render(unflushed), "before flushing")
  end

  def test_hash_is_serializable_and_compact
    event = Mayu::Session::Event.new(:timed_out, session_id: ID)
    hash = JSON.parse(JSON.generate(event.to_hash))

    assert_equal({"type" => "mayu.session", "action" => "timed_out", "session_id" => ID}, hash)
  end

  def test_unknown_actions_are_rejected
    assert_raises(ArgumentError) { Mayu::Session::Event.new(:exploded, session_id: ID) }
  end

  private

  def render(event)
    output = StringIO.new
    output.define_singleton_method(:winsize) { [24, 120] }
    terminal = Console::Output::Terminal.new(output, format: Console::Terminal::XTerm)
    Console::Logger.new(terminal).info("session", event:)
    output.string
  end
end
