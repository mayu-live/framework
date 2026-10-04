# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console/event/generic"

require_relative "event_formatter"

module Mayu
  class Session
    # One step in a session's life, as a Console event. The session, its
    # store and the server app emit these; Console::Terminal::Formatter::
    # MayuSession draws them as one coloured line on terminals and as plain
    # text in log files, and the JSON output writes #to_hash as it is.
    class Event < Console::Event::Generic
      TYPE = :"mayu.session"

      ACTIONS = %i[
        initializing
        starting
        stopping
        navigating
        resuming
        resuming_transferred
        transfer_queued
        stream_finished
        timed_out
      ].freeze

      attr_reader :action, :session_id, :path, :flushed

      def initialize(action, session_id:, path: nil, flushed: nil)
        unless ACTIONS.include?(action)
          raise ArgumentError, "unknown session event action: #{action.inspect}"
        end

        @action = action
        @session_id = session_id.to_s
        @path = path
        @flushed = flushed
      end

      def to_hash
        {type: TYPE, action: @action, session_id: @session_id, path: @path, flushed: @flushed}.compact
      end
    end
  end
end
