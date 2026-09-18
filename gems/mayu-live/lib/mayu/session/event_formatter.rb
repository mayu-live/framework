# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console/output/terminal"

module Console
  module Terminal
    module Formatter
      # Draws a Mayu::Session::Event as one line. Console picks formatters up
      # from this namespace when it creates a terminal output, so this file
      # must be loaded before the first log line.
      #
      # Styles resolve to nothing on the plain text format used for log
      # files, so the same code writes colour to a terminal and plain text
      # to a file.
      class MayuSession
        KEY = :"mayu.session"

        # Each step in a session's life has its own colour, so a busy log
        # can be read by colour alone: a session begins in cyan and green,
        # moves in magenta, pauses and resumes in yellow, ends in plain cyan
        # and is reaped in red. Steps that begin something are bold, steps
        # that end something are not. 95 and 96 are bright magenta and
        # bright cyan, which the palette has no names for.
        VERBS = {
          initializing: [:mayu_session_initializing, "Initializing session"],
          starting: [:mayu_session_starting, "Starting session"],
          navigating: [:mayu_session_navigating, "Navigating session"],
          resuming: [:mayu_session_resuming, "Resuming session stream"],
          resuming_transferred: [:mayu_session_resuming, "Resuming transferred session stream"],
          stopping: [:mayu_session_stopping, "Stopping session"],
          stream_finished: [:mayu_session_finished, "Session stream finished for"],
          transfer_queued: [:mayu_session_transfer, "Session transfer queued for"],
          timed_out: [:mayu_session_timed_out, "Deleting timed out session"]
        }.freeze

        def initialize(terminal)
          @terminal = terminal
          # Ids are long and random; dimmed, they stay readable without
          # drawing the eye away from what happened.
          @terminal[:mayu_session_id] ||= @terminal.style(nil, nil, :faint)
          @terminal[:mayu_session_path] ||= @terminal.style(:blue, nil, :bold)
          @terminal[:mayu_session_initializing] ||= @terminal.style(nil, nil, 96, :bold)
          @terminal[:mayu_session_starting] ||= @terminal.style(:green, nil, :bold)
          @terminal[:mayu_session_navigating] ||= @terminal.style(:magenta)
          @terminal[:mayu_session_resuming] ||= @terminal.style(:yellow, nil, :bold)
          @terminal[:mayu_session_stopping] ||= @terminal.style(:yellow)
          @terminal[:mayu_session_finished] ||= @terminal.style(:cyan)
          @terminal[:mayu_session_transfer] ||= @terminal.style(nil, nil, 95)
          @terminal[:mayu_session_timed_out] ||= @terminal.style(:red)
        end

        def format(event, stream, verbose: false, width: 80)
          action = event[:action]&.to_sym
          style, verb = VERBS.fetch(action, [nil, "Session #{action}"])
          id = paint(:mayu_session_id, event[:session_id])

          line = "#{paint(style, verb)} #{id}"
          line += " at #{paint(:mayu_session_path, event[:path])}" if action == :initializing
          line += " to #{paint(:mayu_session_path, event[:path])}" if action == :navigating
          line += paint(:mayu_session_resuming, " before flushing") if event[:flushed] == false

          stream.puts line
        end

        private

        def paint(style, text)
          return text.to_s unless style

          "#{@terminal[style]}#{text}#{@terminal.reset}"
        end
      end
    end
  end
end
