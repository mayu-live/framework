# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console/output/terminal"

require_relative "listen_event"

module Console
  module Terminal
    module Formatter
      # Draws a Mayu::Server::ListenEvent as one line: what started, and the
      # address it listens on in the colour paths and links share. The
      # collector's socket is internal, so its line stays plain. Console
      # picks formatters up from this namespace when it creates a terminal
      # output, so this file must be loaded before the first log line.
      #
      # Styles resolve to nothing on the plain text format used for log
      # files, so the same code writes colour to a terminal and plain text
      # to a file.
      class MayuListen
        KEY = Mayu::Server::ListenEvent::TYPE

        def initialize(terminal)
          @terminal = terminal
          @terminal[:mayu_listen_start] ||= @terminal.style(:green)
          @terminal[:mayu_listen_url] ||= @terminal.style(:blue, nil, :bold)
        end

        def format(event, stream, verbose: false, width: 80)
          service = event[:service]&.to_sym
          label = Mayu::Server::ListenEvent::SERVICES.fetch(service, service.to_s)
          plain = service == :collector

          stream.puts(
            "#{paint(:mayu_listen_start, "Starting #{label} on", plain:)} " \
              "#{paint(:mayu_listen_url, event[:url], plain:)}"
          )
        end

        private

        def paint(style, text, plain: false)
          return text.to_s if plain

          "#{@terminal[style]}#{text}#{@terminal.reset}"
        end
      end
    end
  end
end
