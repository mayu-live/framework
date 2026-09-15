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
        source.modules
      end
    end

    # Serves a prebuilt bundle. This is the only provider production needs, so
    # it must stay loadable with klenod-runtime and klenod-rack alone.
    class RuntimeProvider < Provider
      def self.load(bundle_path, source_root:, assets_dir:)
        new(
          ::Klenod::Runtime.load_bundle(bundle_path, source_root:),
          assets_dir:
        )
      end

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
