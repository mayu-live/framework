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

      # The source around every frame of a rewritten backtrace that points
      # into a module with a source map, grouped by file. Each file gets one
      # excerpt per run of nearby lines, as
      # `{file:, excerpts: [[{line:, text:, highlight:}, ...], ...]}`.
      def source_excerpts(error, context: 2)
        frames = Array(error.backtrace).filter_map { parse_frame(it) }

        frames.group_by(&:first).filter_map do |file, entries|
          module_id, source = module_source(file)
          next unless source

          lines = source.lines.map(&:chomp)
          numbers = entries.map(&:last).uniq
          excerpts =
            excerpt_ranges(numbers, context, lines.length).map do |range|
              range.map do |number|
                {line: number, text: lines[number - 1], highlight: numbers.include?(number)}
              end
            end

          {file: module_id, excerpts:}
        end
      end

      # The module and full source of the first backtrace frame that points
      # into a module with a source map, with the line the frame names, as
      # `{file:, source:, line:}`. Nil when no frame does.
      def source_location(error)
        Array(error.backtrace).each do |frame|
          file, line = parse_frame(frame)
          next unless file

          module_id, source = module_source(file)
          return {file: module_id, source:, line:} if source
        end

        nil
      end

      private

      def source_maps
        source.modules
      end

      def parse_frame(frame)
        match = /\A(?<file>.*):(?<line>\d+):in /.match(frame.to_s)
        match && [match[:file], match[:line].to_i]
      end

      # Frames are matched the way the backtrace rewriter indexes modules:
      # by module key, path or evaluation path. Returns the module id and
      # the original source.
      def module_source(file)
        source_maps.each do |key, mod|
          next unless mod.respond_to?(:source_map)

          source_map = mod.source_map
          next unless source_map

          paths = [key.to_s]
          paths << mod.path.to_s if mod.respond_to?(:path)
          paths << mod.eval_path.to_s if mod.respond_to?(:eval_path)

          return [key.to_s, source_map.input] if paths.include?(file)
        end

        nil
      end

      def excerpt_ranges(numbers, context, last_line)
        numbers.sort.each_with_object([]) do |number, ranges|
          range = [number - context, 1].max..[number + context, last_line].min
          previous = ranges.last

          if previous && range.begin <= previous.end + 1
            ranges[-1] = previous.begin..[previous.end, range.end].max
          else
            ranges << range
          end
        end
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

      # Evaluates every module in the bundle. The production server does this
      # in the controller before forking, so the workers share the evaluated
      # modules and answer their first request without evaluating anything.
      def preload
        source.preload
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
