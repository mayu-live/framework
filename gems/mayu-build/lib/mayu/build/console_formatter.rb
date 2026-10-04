# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console/output/terminal"

require "mayu/hot_reload"
require_relative "error_report"
require_relative "update_event"

module Console
  module Terminal
    module Formatter
      # Draws a Mayu::Build::UpdateEvent. Console's terminal output picks
      # formatters up from this namespace when it is created, so this file has
      # to be loaded before the first log line is written.
      #
      # Styles resolve to nothing on the plain text format used for log
      # files, so the same code writes colour to a terminal and plain text to
      # a file.
      class MayuUpdate
        KEY = Mayu::Build::UpdateEvent::TYPE

        def initialize(terminal)
          @terminal = terminal
          @terminal[:mayu_update_success] ||= @terminal.style(:green, nil, :bold)
          @terminal[:mayu_update_failure] ||= @terminal.style(:red, nil, :bold)
          @terminal[:mayu_update_dim] ||= @terminal.style(nil, nil, :faint)
          @terminal[:mayu_update_changed] ||= @terminal.style(:yellow)
          @terminal[:mayu_update_added] ||= @terminal.style(:green)
          @terminal[:mayu_update_removed] ||= @terminal.style(:red)
        end

        def format(event, stream, verbose: false, width: 80)
          completed = event[:status] == :completed
          status_style = completed ? :mayu_update_success : :mayu_update_failure

          stream.puts(
            "#{paint(status_style, "Update ##{event[:version]} #{event[:status]}")} " \
              "#{paint(:mayu_update_dim, "(#{format_duration(event[:duration])})")}"
          )
          list(stream, "changed files", event[:changed], "~", :mayu_update_changed)
          list(stream, "removed files", event[:removed], "-", :mayu_update_removed)

          if completed
            format_modules(event, stream)
          else
            format_errors(event, stream)
          end
        end

        private

        def format_modules(event, stream)
          list(stream, "reloaded", event[:reloaded], "~", :mayu_update_changed)
          list(stream, "reevaluated", event[:reevaluated], "*", :mayu_update_success)
          list(stream, "removed modules", event[:removed_modules], "-", :mayu_update_removed)

          assets = event[:assets]
          if assets.values.any? { !it.empty? }
            stream.puts "  assets:"
            assets[:added].each { stream.puts "    #{paint(:mayu_update_added, "+ #{it}")}" }
            assets[:changed].each { stream.puts "    #{paint(:mayu_update_changed, "~ #{it}")}" }
            assets[:removed].each { stream.puts "    #{paint(:mayu_update_removed, "- #{it}")}" }
          end

          modules = event.values_at(:reloaded, :reevaluated, :removed_modules)
          if modules.all?(&:empty?) && assets.values.all?(&:empty?)
            stream.puts "  #{paint(:mayu_update_dim, "modules: no loaded graph modules affected")}"
          end
        end

        def format_errors(event, stream)
          event[:errors].each do |report|
            report = Mayu::HotReload::ErrorReport.new(**report)
            text = Mayu::Build::ErrorReport.render(report, ansi: @terminal.colors?)
            text.each_line do |line|
              stream.puts(line.strip.empty? ? line.chomp : "  #{line.chomp}")
            end
          end
        end

        def list(stream, label, values, marker, style)
          return if values.empty?

          stream.puts "  #{label}:"
          values.each { stream.puts "    #{paint(style, marker)} #{it}" }
        end

        def paint(style, text)
          "#{@terminal[style]}#{text}#{@terminal.reset}"
        end

        def format_duration(seconds)
          "%.1fms" % (seconds.to_f * 1_000)
        end
      end
    end
  end
end
