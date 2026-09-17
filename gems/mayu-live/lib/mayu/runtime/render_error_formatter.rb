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
          # Tags: magenta sigil, bright magenta name. Components: yellow
          # sigil, bold yellow name. 95 is the bright magenta code, which
          # the palette has no name for.
          @terminal[:mayu_error_element_sigil] ||= @terminal.style(:magenta)
          @terminal[:mayu_error_element] ||= @terminal.style(nil, nil, 95)
          @terminal[:mayu_error_component_sigil] ||= @terminal.style(:yellow)
          @terminal[:mayu_error_component] ||= @terminal.style(:yellow, nil, :bold)
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

          tree_lines = tree_lines(event[:tree_path] || [])
          unless tree_lines.empty?
            stream.puts ""
            tree_lines.each_with_index do |line, depth|
              stream.puts "#{"  " * depth}#{line}"
            end
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

        # One line per component that comes from a module, each one level
        # deeper. Everything between two of those, elements and internal
        # components alike, shares a line.
        def tree_lines(tree_path)
          lines = []
          run = nil

          tree_path.each do |node|
            if node[:path]
              lines << format_tree_node(node)
              run = nil
            else
              run ||= lines.push([]).last
              run << format_tree_node(node)
            end
          end

          lines.map { |line| line.is_a?(Array) ? line.join(" > ") : line }
        end

        # Elements as in Haml, components with the module they come from,
        # each kind in its own colours.
        def format_tree_node(node)
          name = node[:name].to_s
          kind = (node[:component] || node[:path]) ? :mayu_error_component : :mayu_error_element
          sigil = name.start_with?("#") ? "" : paint(:"#{kind}_sigil", "%")
          text = sigil + paint(kind, name)
          path = node[:path]
          path ? "#{text} #{paint(:mayu_error_dim, "(#{path})")}" : text
        end

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
