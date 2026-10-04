# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  module Runtime
    # Draws a vnode tree path in a Console formatter, the way render errors
    # show where they happened. The including formatter provides @terminal
    # and #paint, and calls #define_tree_path_styles from #initialize.
    module TreePathFormat
      private

      def define_tree_path_styles
        @terminal[:mayu_error_dim] ||= @terminal.style(nil, nil, :faint)
        # Tags: magenta sigil, bright magenta name. Components: yellow
        # sigil, bold yellow name. 95 is the bright magenta code, which
        # the palette has no name for.
        @terminal[:mayu_error_element_sigil] ||= @terminal.style(:magenta)
        @terminal[:mayu_error_element] ||= @terminal.style(nil, nil, 95)
        @terminal[:mayu_error_component_sigil] ||= @terminal.style(:yellow)
        @terminal[:mayu_error_component] ||= @terminal.style(:yellow, nil, :bold)
        @terminal[:mayu_error_invalid] ||= @terminal.style(:red, nil, :bold)
      end

      def write_tree_path(stream, tree_path)
        tree_lines(tree_path || []).each_with_index do |line, depth|
          stream.puts "#{"  " * depth}#{line}"
        end
      end

      # One line per component that comes from a module, and per invalid
      # element, each one level deeper. Everything between two of those,
      # elements and internal components alike, shares a line.
      def tree_lines(tree_path)
        lines = []
        run = nil

        tree_path.each do |node|
          if node[:path] || node[:invalid]
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
      # each kind in its own colours. Invalid elements are red.
      def format_tree_node(node)
        name = node[:name].to_s
        return paint(:mayu_error_invalid, "%#{name}") if node[:invalid]

        kind = (node[:component] || node[:path]) ? :mayu_error_component : :mayu_error_element
        sigil = name.start_with?("#") ? "" : paint(:"#{kind}_sigil", "%")
        text = sigil + paint(kind, name)
        path = node[:path]
        path ? "#{text} #{paint(:mayu_error_dim, "(#{path})")}" : text
      end
    end
  end
end
