# frozen_string_literal: true

require_relative "../klenod/provider"

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
