# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    class Exports < Module
      def initialize(mod, source, path)
        @mod = mod
        @path = path
        module_eval(source, path, 1)
      end

      def import(path) = @mod.import(path)

      def add_asset(asset) = @mod.add_asset(asset)
    end

    class Mod < Module
      attr_accessor :order
      attr_reader :path
      attr_reader :dependants
      attr_reader :dependencies
      attr_reader :system
      attr_reader :source_map
      attr_reader :assets
      attr_reader :imports
      attr_reader :dependency_nodes

      def initialize(system, path)
        @order = Float::INFINITY
        @system = system
        @path = path
        @dependants = Set.new
        @dependencies = Set.new
        @system.register(@path, self)
        @source = nil
        @source_map = nil
        @assets = Set.new
        @imports = {}
        @dependency_nodes = Set.new
      end

      def to_s
        File.join("MAYU_ROOT", @path)
      end

      def const_missing(const)
        if const == :Exports
          reload(reload_source: false)

          if exports = const_get(:Exports)
            return exports
          end
        end

        super
      end

      def marshal_dump
        [
          @order,
          @path,
          @dependants,
          @dependencies,
          @source,
          @assets,
          @source_map,
          @imports,
          @dependency_nodes
        ]
      end

      def marshal_load(a)
        @order,
        @path,
        @dependants,
        @dependencies,
        @source,
        @assets,
        @source_map,
        @imports,
        @dependency_nodes =
          a
        @imports ||= {}
        @dependency_nodes ||= Set.new
        Registry[@path] = self
      end

      def reload(reload_source: true)
        old_exports =
          if const_defined?(:Exports)
            # Console.logger.info(self, "Reloading #{@path}")
            const_get(:Exports)
          else
            # Console.logger.info(self, "Loading #{@path}")
            nil
          end

        if reload_source
          begin
            reload_source!
          rescue => e
            pp e
            puts e.backtrace
            return
          end
        end

        @assets.clear

        path = @path

        exports =
          begin
            Exports.new(self, @source, path)
          rescue => e
            puts e
            puts e.backtrace.first(5)
            return
          end

        remove_const(:Exports) if const_defined?(:Exports)
        const_set(:Exports, exports)
      end

      def reload_source!
        if staged_source_update?
          @source = @staged_source
          @source_map = @staged_source_map
          @imports = @staged_imports
          clear_staged_source_update!
        else
          @source, @source_map, @imports = @system.read_source(@path)
        end

        @dependency_nodes = @system.resolve_dependencies_for(self, @imports)
      end

      def stage_source_update!
        source, source_map, imports = @system.read_source(@path)
        return false if source == @source

        @staged_source = source
        @staged_source_map = source_map
        @staged_imports = imports

        true
      end

      def import(path)
        @system.import(path, @path)
      end

      def add_asset(asset)
        @assets.add(asset.filename)
        @system.add_asset(asset)
      end

      def exports
        self::Exports.constants
      end

      def absolute_path
        File.join(@system.root, @path)
      end

      private

      def staged_source_update?
        defined?(@staged_source) && defined?(@staged_source_map) &&
          defined?(@staged_imports)
      end

      def clear_staged_source_update!
        remove_instance_variable(:@staged_source)
        remove_instance_variable(:@staged_source_map)
        remove_instance_variable(:@staged_imports)
      end
    end
  end
end
