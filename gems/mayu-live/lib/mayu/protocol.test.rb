#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "minitest/autorun"
require "json"

require_relative "session"
require_relative "runtime/engine"
require_relative "server/event_stream"

# client/protocol.json describes the wire protocol once. This test holds the
# server to it, and client/src/protocol-manifest.test.ts holds the browser
# runtime to it, so the two sides can't drift apart unnoticed.
class Mayu::ProtocolTest < Minitest::Test
  MANIFEST =
    JSON.parse(File.read(File.join(__dir__, "client", "protocol.json"))).freeze

  def test_stream_content_type
    assert_equal(
      MANIFEST.fetch("streamContentType"),
      Mayu::Server::EventStream::CONTENT_TYPE
    )
  end

  def test_commands
    commands = Mayu::Runtime::Commands
    defined =
      commands
        .constants
        .map { commands.const_get(it) }
        .select { it.is_a?(Class) && it < commands::CommandData }
        .to_h { [it.name[/[^:]+\z/], it.members.map(&:to_s)] }

    assert_equal(MANIFEST.fetch("commands"), defined)
  end

  def test_events
    events = Mayu::Session::Events
    defined =
      events
        .constants
        .grep(/Event\z/)
        .select { events.const_get(it) < Data }
        .map { it.to_s.delete_suffix("Event") }

    assert_equal(MANIFEST.fetch("events").sort, defined.sort)

    MANIFEST.fetch("events").each do |name|
      error =
        assert_raises(events::InvalidEventError) { events.parse([name]) }
      assert_includes(error.message, name)
    end
  end

  def test_error_codes
    source = File.read(File.join(__dir__, "server", "app.rb"))
    sent = source.scan(/error_response\(\s*\d+,\s*"([A-Z_]+)"/).flatten.uniq

    assert_equal(MANIFEST.fetch("errorCodes").keys.sort, sent.sort)
  end

  def test_continuous_events
    assert_equal(
      MANIFEST.fetch("continuousEvents").sort,
      Mayu::Runtime::VNodes::VDocument::CONTINUOUS_EVENT_TYPES.sort
    )
  end

  def test_element_methods
    handle = Mayu::Runtime::ElementHandle
    methods =
      handle.public_instance_methods(false) - %i[inspect marshal_dump]

    assert_equal(
      MANIFEST.fetch("elementMethods").sort,
      methods.map(&:to_s).sort
    )
  end
end
