# frozen_string_literal: true

require "console/output/terminal"

module Console
  module Terminal
    module Formatter
      class MayuStateUpdateDuringRender
        KEY = :"mayu.state_update_during_render"

        def initialize(terminal)
          @terminal = terminal
          @terminal[:mayu_warning_title] ||= @terminal.style(:yellow, nil, :bold)
          @terminal[:mayu_warning_location] ||= @terminal.style(:magenta, nil, :bold)
          @terminal[:mayu_warning_file] ||= @terminal.style(nil, nil, :bold)
          @terminal[:mayu_warning_dim] ||= @terminal.style(nil, nil, :faint)
          @terminal[:mayu_warning_highlight] ||= @terminal.style(:yellow)
        end

        def format(event, stream, verbose: false, width: 80)
          stream.puts(
            "#{paint(:mayu_warning_title, "State update during render")} " \
              "#{paint(:mayu_warning_dim, "at")} " \
              "#{paint(:mayu_warning_location, event[:location])}"
          )

          event[:sources].each do |source|
            stream.puts ""
            stream.puts paint(:mayu_warning_file, source[:file])
            source[:excerpts].each_with_index do |excerpt, index|
              stream.puts "  #{paint(:mayu_warning_dim, "...")}" if index > 0
              excerpt.each { |line| stream.puts format_line(line) }
            end
          end
        end

        private

        def format_line(line)
          text = sprintf("%s %3d: %s", line[:highlight] ? ">" : " ", line[:line], line[:text])
          line[:highlight] ? paint(:mayu_warning_highlight, text) : text
        end

        def paint(style, text)
          "#{@terminal[style]}#{text}#{@terminal.reset}"
        end
      end
    end
  end
end
