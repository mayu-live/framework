# frozen_string_literal: true

module Mayu
  module Klenod
    class Provider
      attr_reader :source, :assets_dir

      def initialize(source, assets_dir: nil)
        @source = source
        @assets_dir = assets_dir
      end

      def entry(specifier)
        if source.respond_to?(:entry)
          source.entry(specifier)
        else
          source.exports(specifier)
        end
      end

      def exports(reference)
        return reference if reference.is_a?(Module)

        if reference.respond_to?(:exports)
          reference.exports
        else
          source.exports(reference)
        end
      end

      def module_id_for(reference)
        source.module_id_for(reference)
      rescue KeyError
        entry(reference).id
      end

      def component_resolver
        @component_resolver ||= ComponentResolver.new(self)
      end

      def asset_references_for_module(reference, **options)
        source.asset_references_for_module(reference, **options)
      end

      def assets_for_module(reference, **options)
        source.assets_for_module(reference, **options)
      end

      def asset(output_path)
        source.asset(output_path)
      end

      def asset_bytes(output_path)
        if source.respond_to?(:asset_bytes)
          return source.asset_bytes(output_path, assets_dir:)
        end

        unless assets_dir
          raise ArgumentError, "assets_dir is required for a runtime bundle"
        end

        File.binread(File.join(assets_dir, output_path.delete_prefix("/")))
      end

      def asset_base
        source.base
      end

      def asset_origin
        source.asset_origin
      end

      # Absolute path of a module's source file, used to show an excerpt for a
      # build error that names a module but does not carry its source.
      def absolute_path(module_id)
        source.graph.absolute_path(module_id) if source.respond_to?(:graph)
      end

      # Whether a module's generated line numbers can still be translated back
      # to its original source. A module that fails to load is replaced in the
      # graph by a placeholder carrying only the error, so its source map is
      # gone and its backtrace still points at generated Ruby.
      def source_mapped?(module_id)
        return false unless source.respond_to?(:graph)

        mod = source.graph.mods[::Klenod::Build::ModuleId.parse(module_id.to_s)]
        mod.respond_to?(:source_map) && !mod.source_map.nil?
      rescue ::Klenod::Build::Error, ArgumentError
        false
      end

      def format_exception(error, source_path: nil)
        ::Klenod::Runtime::BacktraceRewriter.new(source_maps).format_exception(
          error,
          source_path:
        )
      end

      def rewrite_exception(error)
        ::Klenod::Runtime::BacktraceRewriter.new(source_maps).rewrite_exception(
          error
        )
      end

      private

      def source_maps
        return source.graph.mods if source.respond_to?(:graph)
        return source.modules if source.respond_to?(:modules)

        {}
      end
    end

    class DevelopmentProvider < Provider
      def context
        source
      end

      def apply_update(event, entry:)
        source.apply_update(event, entry:, assets_dir:)
      end
    end

    class RuntimeProvider < Provider
      def module_id_for(reference)
        # Runtime component classes use their evaluation path, while bundle
        # lookups use source-relative paths or canonical module IDs.
        if reference.is_a?(String) && source.source_root
          reference = reference.delete_prefix("#{source.source_root}/")
        end
        super
      end
    end
  end
end
