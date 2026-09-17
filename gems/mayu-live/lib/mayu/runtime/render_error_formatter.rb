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
      # Draws a Mayu::Runtime::RenderErrorEvent: the error, the app frames,
      # a count of the frames through Mayu, and the source around each app
      # frame. Console picks formatters up from this namespace when it
      # creates a terminal output, so this file must be loaded before the
      # first log line.
      #
      # Styles resolve to nothing on the plain text format used for log
      # files, so the same code writes colour to a terminal and plain text
      # to a file.
      class MayuRenderError
        KEY = :"mayu.render_error"

        def initialize(terminal)
          @terminal = terminal
          @terminal[:mayu_error_title] ||= @terminal.style(:red, nil, :bold)
          @terminal[:mayu_error_dim] ||= @terminal.style(nil, nil, :faint)
          @terminal[:mayu_error_file] ||= @terminal.style(nil, nil, :bold)
          @terminal[:mayu_error_highlight] ||= @terminal.style(:red)
        end

        def format(event, stream, verbose: false, width: 80)
          root = root_prefix(event[:root])

          stream.puts "#{paint(:mayu_error_title, event[:error])}: #{event[:message]}"

          event[:backtrace].each do |frame|
            stream.puts "  #{frame.to_s.delete_prefix(root)}"
          end

          hidden = event[:hidden_frames].to_i
          if hidden > 0
            stream.puts "  #{paint(:mayu_error_dim, "#{hidden} more frames through Mayu")}"
          end

          event[:sources].each do |source|
            stream.puts ""
            stream.puts paint(:mayu_error_file, source[:file].to_s.delete_prefix(root))
            source[:excerpts].each_with_index do |excerpt, index|
              stream.puts "  #{paint(:mayu_error_dim, "...")}" if index > 0
              excerpt.each { |line| stream.puts format_line(line) }
            end
          end
        end

        private

        def format_line(line)
          text = sprintf("%s %3d: %s", line[:highlight] ? ">" : " ", line[:line], line[:text])
          line[:highlight] ? paint(:mayu_error_highlight, text) : text
        end

        def root_prefix(root)
          root = root.to_s
          return root if root.empty? || root.end_with?("/")

          "#{root}/"
        end

        def paint(style, text)
          "#{@terminal[style]}#{text}#{@terminal.reset}"
        end
      end
    end
  end
end
