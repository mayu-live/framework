# frozen_string_literal: true

require "klenod/build/resolution_error_formatter"

module Mayu
  module Klenod
    # Normalizes a hot-reload failure into the fields the terminal logger and
    # the browser overlay both need.
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
    ErrorReport =
      Data.define(
        :type,
        :detail,
        :file,
        :line,
        :column,
        :source,
        :hints,
        :backtrace
      ) do
        def self.from(error, module_id: nil, provider: nil)
          case error
          when ::Klenod::Build::SourceError
            from_source_error(error, module_id:)
          when ::Klenod::Build::ResolveError
            from_resolve_error(error, module_id:, provider:)
          else
            from_unknown(error, module_id:)
          end
        end

        def self.from_source_error(error, module_id:)
          new(
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

          new(
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

        def self.from_unknown(error, module_id:)
          new(
            type: error.class.name,
            detail: error.respond_to?(:message) ? error.message.to_s : error.inspect,
            file: module_id.to_s,
            line: nil,
            column: nil,
            source: nil,
            hints: [],
            backtrace:
              error.respond_to?(:backtrace) ? Array(error.backtrace) : []
          )
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
          :read_source

        # "app:/pages/demos/CustomElement.tsx:3:20"
        def location
          return file if line.nil?

          "#{file}:#{[line, column].compact.join(":")}"
        end

        def render(ansi: true)
          body =
            ::Klenod::Build::SourceExcerpt.message(
              module_id: file,
              line:,
              column:,
              kind: type,
              source:,
              message: detail,
              hints:,
              ansi:
            )

          return body if backtrace.empty?

          [body, backtrace_section].join("\n\n")
        end

        private

        def backtrace_section
          "Backtrace:\n#{backtrace.map { "  #{it}" }.join("\n")}"
        end
      end
  end
end
