# frozen_string_literal: true

module Mayu
  module Test
    class MinitestReporter < Minitest::StatisticsReporter
      COLORS = {
        reset: "\e[0m",
        dim: "\e[2m",
        success: "\e[1;32m",
        failure: "\e[1;31m",
        skipped: "\e[1;33m"
      }.freeze

      def initialize(io = $stdout, options = {}, env: ENV)
        super(io, options)
        @env = env
        @test_results = []
      end

      def record(result)
        super
        test_results << result
      end

      def report
        super
        report_files
        report_failures
        report_summary
      end

      private

      attr_reader :env, :test_results

      def report_files
        grouped_results.each do |path, results|
          failed = results.any? { failed_result?(it) }
          marker = failed ? color(:failure, "✗") : color(:success, "✓")
          io.puts "#{marker} #{path} #{color(:dim, "(#{results.length})")}"

          results.sort_by(&:name).each do |result|
            io.puts "  #{result_marker(result)} #{test_name(result.name)}"
          end
        end
      end

      def report_failures
        failed_results = test_results.select { failed_result?(it) }
        return if failed_results.empty?

        io.puts
        io.puts color(:failure, "Failed Tests #{failed_results.length}")
        failed_results.each_with_index do |result, index|
          io.puts
          io.puts color(
            :failure,
            "#{index + 1}. #{result.klass} > #{test_name(result.name)}"
          )
          io.puts indent(result.to_s, "   ")
        end
      end

      def report_summary
        failed_tests = test_results.count { failed_result?(it) }
        passed_tests = count - failed_tests - skips
        failed_files =
          grouped_results.count do |_path, results|
            results.any? { failed_result?(it) }
          end
        passed_files = grouped_results.length - failed_files

        io.puts
        io.puts summary_line(
          "Test Files",
          passed_files,
          failed_files,
          grouped_results.length
        )
        io.puts summary_line(
          "Tests",
          passed_tests,
          failed_tests,
          count,
          skipped: skips
        )
        io.puts "#{color(:dim, "Assertions".ljust(11))} #{assertions}"
        io.puts "#{color(:dim, "Duration".ljust(11))} #{format_duration(total_time)}"
      end

      def grouped_results
        @grouped_results ||= test_results.group_by(&:klass).sort.to_h
      end

      def summary_line(label, passed_count, failed_count, total_count, skipped: 0)
        values = []
        values << color(:success, "#{passed_count} passed") if
          passed_count.positive?
        values << color(:failure, "#{failed_count} failed") if
          failed_count.positive?
        values << color(:skipped, "#{skipped} skipped") if skipped.positive?
        "#{color(:dim, label.ljust(11))} #{values.join(color(:dim, " | "))} #{color(:dim, "(#{total_count})")}"
      end

      def result_marker(result)
        return color(:success, "✓") if result.passed?
        return color(:skipped, "○") if result.skipped?

        color(:failure, "✗")
      end

      def failed_result?(result)
        !result.passed? && !result.skipped?
      end

      def test_name(name)
        name.to_s.delete_prefix("test_").tr("_", " ")
      end

      def format_duration(duration)
        return format("%.0fms", duration * 1000) if duration < 1

        format("%.2fs", duration)
      end

      def color(name, value)
        return value.to_s if env.key?("NO_COLOR")

        "#{COLORS.fetch(name)}#{value}#{COLORS.fetch(:reset)}"
      end

      def indent(value, prefix)
        value.lines.map { "#{prefix}#{it}" }.join
      end
    end

    module MinitestReporterPlugin
      class << self
        attr_accessor :output
      end

      module_function

      def minitest_plugin_init(options)
        io = output || options[:io]
        Minitest.reporter.reporters.replace([MinitestReporter.new(io, options)])
      end
    end
  end
end
