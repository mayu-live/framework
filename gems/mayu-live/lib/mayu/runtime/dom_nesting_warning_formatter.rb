# frozen_string_literal: true

require "console/output/terminal"

require_relative "tree_path_format"

module Console
  module Terminal
    module Formatter
      class MayuInvalidDOMNesting
        include Mayu::Runtime::TreePathFormat

        KEY = :"mayu.invalid_dom_nesting"

        def initialize(terminal)
          @terminal = terminal
          @terminal[:mayu_warning_title] ||= @terminal.style(:yellow, nil, :bold)
          @terminal[:mayu_warning_location] ||= @terminal.style(:magenta, nil, :bold)
          @terminal[:mayu_warning_dim] ||= @terminal.style(nil, nil, :faint)
          @terminal[:mayu_warning_tag] ||= @terminal.style(:cyan)
          define_tree_path_styles
        end

        def format(event, stream, verbose: false, width: 80)
          stream.puts(
            "#{paint(:mayu_warning_title, "Invalid DOM nesting")} " \
              "#{paint(:mayu_warning_dim, "in")} " \
              "#{paint(:mayu_warning_location, event[:location])}"
          )
          stream.puts(event[:message].to_s.gsub(/<[^<>]+>/) { paint(:mayu_warning_tag, it) })

          unless (event[:tree_path] || []).empty?
            stream.puts ""
            write_tree_path(stream, event[:tree_path])
          end
        end

        private

        def paint(style, text)
          "#{@terminal[style]}#{text}#{@terminal.reset}"
        end
      end
    end
  end
end
