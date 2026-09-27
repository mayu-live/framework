# frozen_string_literal: true

require "mayu/klenod/provider"
require_relative "error_report"

module Mayu
  module Build
    # Serves modules from a live build context, so it can apply updates and
    # read back sources for error reports.
    class DevelopmentProvider < Klenod::Provider
      def context
        source
      end

      def apply_update(event, entry:)
        source.apply_update(event, entry:, assets_dir:)
      end

      def asset_bytes(output_path)
        source.asset_bytes(output_path, assets_dir:)
      end

      # Absolute path of a module's source file, used to show an excerpt for a
      # build error that names a module but does not carry its source.
      def absolute_path(module_id)
        source.graph.absolute_path(module_id)
      end

      # A development report for any error. Build errors already format
      # themselves; anything else gets its backtrace rewritten to the original
      # sources, in place, so call this once per error.
      def format_exception(error, ansi: true)
        case error
        when ::Klenod::Build::SourceError
          ansi ? error.message : ::Klenod::Build::SourceExcerpt.strip(error.message)
        when ::Klenod::Build::ResolveError
          ::Klenod::Build::ResolutionErrorFormatter.format(error, ansi:)
        else
          ::Klenod::Build::ExceptionFormatter.format(error, mods: source.graph.mods, ansi:)
        end
      end

      # A build error raised while serving a request, as the same report the
      # hot reloader prints: the source excerpt and hints, no backtrace. Nil
      # for any other error, which keeps its backtrace.
      def build_error_report(error)
        case error
        when ::Klenod::Build::SourceError, ::Klenod::Build::ResolveError
          ErrorReport.render(ErrorReport.from(error, provider: self), ansi: false)
        end
      end

      # Whether a module's generated line numbers can still be translated back
      # to its original source. A module that fails to load is replaced in the
      # graph by a placeholder carrying only the error, so its source map is
      # gone and its backtrace still points at generated Ruby.
      def source_mapped?(module_id)
        mod = source.graph.mods[::Klenod::Build::ModuleId.parse(module_id.to_s)]
        mod.respond_to?(:source_map) && !mod.source_map.nil?
      rescue ::Klenod::Build::Error, ArgumentError
        false
      end

      private

      def source_maps
        source.graph.mods
      end
    end
  end
end
