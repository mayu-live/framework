# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Commands
    class Build < Samovar::Command
      MODULE_SPINNER = %w[⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷].freeze
      MODULE_PROGRESS_INTERVAL = 25

      self.description = "Build app for production"

      options do
        option(
          "--filename <string>",
          "Filename of the generated bundle",
          default: "app.mayu-bundle"
        )

        option(
          "--concurrency <number>",
          "Number of concurrent tasks for generating assets",
          default: 4
        ) { it.to_i }
      end

      def call
        require "terminal-table"
        require_relative "../configuration"
        require_relative "../klenod"

        Sync do
          profiler =
            ::Klenod::Build::Profiler.new(
              enabled: true,
              store_events: false,
              progress: ->(event, details) { report_build(event, **details) }
            )
          elapsed =
            Async::Clock.measure do
              Configuration.with(:development) do |config|
                Klenod::Configuration.load(
                  root: config.root,
                  mode: :production
                ).build(
                  output: File.expand_path(options[:filename]),
                  asset_generation_concurrency: options[:concurrency],
                  profiler:
                ) { |event, **details| report_build(event, **details) }
              end
            rescue => e
              Console.logger.error(self, e)
              raise
            end

          puts
          print_completion(options[:filename], elapsed)
        end
      end

      private

      def report_build(event, **details)
        case event
        when :collecting_bundle
          puts "#{style(1, "Entrypoints:")} #{details[:entrypoints].join(", ")}"
          puts
          interactive? ? print(module_progress(0)) : puts(module_progress(0))
        when :collect_module
          report_module_progress(details[:total_records])
        when :bundle_collected
          if interactive?
            print "\e[G\e[2K"
          else
            puts
          end
          puts build_statistics(details[:bundle], details[:assets])
        when :materializing_assets
          puts
          puts style("36;1", "Materializing assets")
        when :asset_materialized
          return unless [:written, :skipped].include?(details[:status])

          asset = details[:asset]
          color = (details[:status] == :written) ? 32 : 33
          puts "  #{style(color, details[:status])} #{relative_path(details[:path])} #{style(2, "(#{asset.metadata[:type] || asset.content_type})")}"
        when :writing_bundle
          puts
          puts style("36;1", "Writing bundle")
        when :bundle_written
          puts "  #{style(32, "written")} #{relative_path(details[:output])}"
        end
      end

      def module_progress(count)
        spinner = MODULE_SPINNER.fetch(@module_progress_index.to_i % MODULE_SPINNER.length)
        @module_progress_index = @module_progress_index.to_i + 1
        "#{style(36, spinner)} Collecting modules: #{style(1, count)}"
      end

      def build_statistics(bundle, assets)
        Terminal::Table.new do |table|
          table.style = {all_separators: true, border: :unicode}
          table.add_row ["Modules", bundle.modules.length]
          table.add_row ["Assets", assets.length]
          table.add_row ["Static assets", assets.count(&:static?)]
          table.add_row ["Generated assets", assets.count(&:generated?)]
        end
      end

      def relative_path(path)
        Pathname.new(path).relative_path_from(Pathname.new(Dir.pwd)).to_s
      end

      def report_module_progress(count)
        if interactive?
          print "\e[G\e[2K#{module_progress(count)}"
        elsif (count % MODULE_PROGRESS_INTERVAL).zero?
          puts module_progress(count)
        end
      end

      def print_completion(filename, elapsed)
        if color?
          puts format(
            "\e[32mBuilt \e[1m%s\e[22m in \e[1m%.2fs\e[0m",
            filename,
            elapsed
          )
        else
          puts format("Built %s in %.2fs", filename, elapsed)
        end
      end

      def style(code, text)
        return text unless color?

        "\e[#{code}m#{text}\e[0m"
      end

      def color? = interactive? && !ENV.key?("NO_COLOR")

      def interactive? = $stdout.tty?
    end
  end
end
