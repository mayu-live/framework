# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console"
require "console/output/terminal"

module Mayu
  class Server
    # Console's terminal output, with the body of each entry behind a bar
    # coloured by its severity: green for info, red for errors. The dev
    # server uses it for $stderr.
    #
    # `call` follows Console::Output::Terminal#call; only the buffer prefix
    # and the event width differ.
    class FramedTerminalOutput < Console::Output::Terminal
      BAR = "│"

      def call(subject = nil, *arguments, name: nil, severity: UNKNOWN, event: nil, **options, &block)
        prefix = build_prefix(name || severity.to_s)
        indent = " " * prefix.size
        frame = @terminal[severity]

        buffer = Buffer.new("#{indent}#{frame}#{BAR}#{@terminal.reset} ")
        # The bar's escape codes take no room on screen.
        indent_size = indent.size + BAR.size + 1

        format_subject(severity, prefix, subject, buffer)

        arguments.each do |argument|
          format_argument(argument, buffer)
        end

        if block_given?
          if block.arity.zero?
            format_argument(yield, buffer)
          else
            yield(buffer, @terminal)
          end
        end

        if event
          format_event(event, buffer, @terminal.width - indent_size)
        end

        if options&.any?
          format_options(options, buffer)
        end

        @stream.write buffer.string
      end
    end
  end
end
