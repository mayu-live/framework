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
    end
  end
end
