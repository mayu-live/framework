# frozen_string_literal: true

require "klenod/build/resolution_error_formatter"
require "mayu/backtrace"
require "mayu/hot_reload"

module Mayu
  module Build
    # Normalizes a hot-reload failure into the fields the terminal logger and
    # the browser overlay both need, as a HotReload::ErrorReport.
    #
    # Klenod reports a build failure through one of two shapes. A SourceError
    # carries the file, location and source text it failed in. A ResolveError
    # names an import it could not resolve, and where that import was written.
    # Both already know everything worth showing, so a backtrace through the
    # build graph is noise and is dropped. Anything else is unexpected, and
    # keeps its backtrace.
    #
    # Rendering goes through Klenod::Build::SourceExcerpt so the terminal block
    # and the browser overlay are laid out by the same code that formats a
    # SourceError's own message.
    module ErrorReport
      def self.from(error, module_id: nil, provider: nil)
        case error
        when ::Klenod::Build::SourceError
          from_source_error(error, module_id:)
        when ::Klenod::Build::ResolveError
          from_resolve_error(error, module_id:, provider:)
        else
          from_unknown(error, module_id:, provider:)
        end
      end

      def self.render(report, ansi: true)
        body =
          ::Klenod::Build::SourceExcerpt.message(
            module_id: report.file,
            line: report.line,
            column: report.column,
            kind: report.type,
            source: report.source,
            message: report.detail,
            hints: report.hints,
            ansi:
          )

        return body if report.backtrace.empty?

        backtrace = report.backtrace.map { "  #{it}" }.join("\n")
        [body, "Backtrace:\n#{backtrace}"].join("\n\n")
      end

      def self.from_source_error(error, module_id:)
        HotReload::ErrorReport.new(
          type: error.kind,
          detail: error.detail.to_s,
          file: (error.module_id || module_id).to_s,
          line: error.line,
          column: error.column,
          source: error.source&.to_s,
          hints: Array(error.hints),
          backtrace: []
        )
      end

      def self.from_resolve_error(error, module_id:, provider:)
        location = error.source_location
        file =
          (location&.path || error.dependency&.importer_id || module_id).to_s

        HotReload::ErrorReport.new(
          type: error.title.to_s,
          detail: resolve_detail(error),
          file:,
          line: location&.line,
          column: location&.column,
          source: read_source(file, provider),
          hints: resolve_hints(error),
          backtrace: []
        )
      end

      # Anything Klenod did not recognize: a module that raised while being
      # evaluated, most often. The backtrace is the only thing pointing at
      # the app, so it is kept, but the frames through the build graph are
      # summarized rather than listed.
      def self.from_unknown(error, module_id:, provider:)
        frames = error.respond_to?(:backtrace) ? Array(error.backtrace) : []
        app_frames, hidden = Mayu::Backtrace.split(frames)
        app_frames << "#{hidden} more frames through the build" if hidden > 0

        line = app_line(frames, module_id, provider)

        HotReload::ErrorReport.new(
          type: error.class.name,
          detail: error.respond_to?(:message) ? error.message.to_s : error.inspect,
          file: module_id.to_s,
          line:,
          column: nil,
          source: line && read_source(module_id.to_s, provider),
          hints: [],
          backtrace: app_frames
        )
      end

      # Only trust a line number when the module's source map is still around
      # to have translated it. Without one the frame points at generated Ruby,
      # and an excerpt would highlight the wrong line.
      def self.app_line(frames, module_id, provider)
        return nil unless module_id
        return nil unless provider.respond_to?(:source_mapped?)
        return nil unless provider.source_mapped?(module_id)

        path = module_id.to_s.sub(%r{\A\w+:/+}, "")

        frames.each do |frame|
          match = /\A(?<file>.*):(?<line>\d+)(?::|\z)/.match(frame.to_s)
          next unless match
          next unless match[:file].end_with?(path)

          return match[:line].to_i
        end

        nil
      end

      # ResolveError bakes its suggestions into #message. We rebuild the
      # sentence without them so they can be listed as hints instead of
      # appearing twice.
      def self.resolve_detail(error)
        return error.message.to_s unless error.resolution_failure?

        specifier = error.requested_specifier.inspect

        case error.reason
        when :incorrect_case then "Incorrect case for #{specifier}"
        else "Could not resolve #{specifier}"
        end
      end

      def self.resolve_hints(error)
        return [] unless error.resolution_failure?

        error.suggestions.map do
          (error.reason == :incorrect_case) ? "Use #{it}" : "Did you mean #{it}?"
        end
      end

      # A ResolveError names the importing module but does not carry its
      # source, so read it back through the build graph.
      def self.read_source(file, provider)
        return nil unless provider.respond_to?(:absolute_path)

        path = provider.absolute_path(::Klenod::Build::ModuleId.parse(file))
        return nil unless path&.file?

        path.read
      rescue ::Klenod::Build::Error, ArgumentError, SystemCallError
        nil
      end

      private_class_method :from_source_error,
        :from_resolve_error,
        :from_unknown,
        :resolve_detail,
        :resolve_hints,
        :read_source,
        :app_line
    end
  end
end
