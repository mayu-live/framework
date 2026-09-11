# frozen_string_literal: true

module Mayu
  module Klenod
    class UpdateLogger
      COLORS = {
        reset: "\e[0m",
        dim: "\e[2m",
        success: "\e[1;32m",
        failure: "\e[1;31m",
        changed: "\e[1;33m",
        added: "\e[32m",
        removed: "\e[31m"
      }.freeze

      def initialize(source_dir:, output: $stdout, error_output: $stderr, env: ENV, provider: nil)
        @source_dir = Pathname.new(source_dir).expand_path
        @output = output
        @error_output = error_output
        @env = env
        @provider = provider
      end

      def log(update:, duration:)
        event = update.event
        result = event.result
        stream = update.success? ? output : error_output
        status = update.success? ? "completed" : "failed"
        color_name = update.success? ? :success : :failure

        stream.puts "#{color(color_name, "Update ##{event.graph_version} #{status}")} #{color(:dim, "(#{duration})")}"
        log_paths(stream, "changed files", event.changed_paths, marker: "~", color_name: :changed)
        log_paths(stream, "removed files", event.removed_paths, marker: "-", color_name: :removed)

        if update.success?
          log_modules(result)
          log_assets(result.asset_changes)
          log_no_graph_changes(result)
        else
          log_errors(stream, update)
        end
      end

      private

      attr_reader :source_dir, :output, :error_output, :env, :provider

      # This is the only place a reload failure is reported. Sessions used to
      # log the exception as well, which repeated the whole backtrace once per
      # open browser tab.
      def log_errors(stream, update)
        update.each_error do |module_id, error|
          report = ErrorReport.from(error, module_id:, provider:)
          stream.puts(indent(report.render(ansi: !env["NO_COLOR"])))
        end
      end

      def indent(text)
        text.lines.map { |line| line.strip.empty? ? line : "  #{line}" }.join
      end

      def log_modules(result)
        log_list(output, "reloaded", result.reloaded_module_ids, marker: "~", color_name: :changed)
        log_list(output, "reevaluated", result.reevaluated_module_ids, marker: "*", color_name: :success)
        log_list(output, "removed modules", result.removed_module_ids, marker: "-", color_name: :removed)
      end

      def log_assets(asset_changes)
        return if asset_changes.empty?

        output.puts "  assets:"
        asset_changes.added.each { |path| output.puts "    #{color(:added, "+")} #{color(:added, path)}" }
        asset_changes.changed.each { |path| output.puts "    #{color(:changed, "~")} #{color(:changed, path)}" }
        asset_changes.removed.each { |path| output.puts "    #{color(:removed, "-")} #{color(:removed, path)}" }
      end

      def log_no_graph_changes(result)
        return unless result.empty?

        output.puts "  #{color(:dim, "modules: no loaded graph modules affected")}"
      end

      def log_paths(stream, label, paths, marker:, color_name:)
        log_list(stream, label, paths.map { |path| relative_path(path) }, marker:, color_name:)
      end

      def log_list(stream, label, values, marker:, color_name:)
        return if values.empty?

        stream.puts "  #{label}:"
        values.each { |value| stream.puts "    #{color(color_name, marker)} #{value}" }
      end

      def relative_path(path)
        pathname = Pathname.new(path)
        pathname = pathname.expand_path if pathname.absolute?
        pathname.relative_path_from(source_dir).to_s
      rescue ArgumentError
        path.to_s
      end

      def color(name, value)
        return value.to_s if env["NO_COLOR"]

        "#{COLORS.fetch(name)}#{value}#{COLORS.fetch(:reset)}"
      end
    end
  end
end
