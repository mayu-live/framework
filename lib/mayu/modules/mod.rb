# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    class Exports < Module
      def initialize(mod, source, path)
        @mod = mod
        @source = source
        @path = path
        module_eval(source, path, 1)
      end

      def import(path) = @mod.import(path)

      def add_asset(asset) = @mod.add_asset(asset)
    end

    class Mod < Module
      attr_reader :order
      attr_reader :path
      attr_reader :dependants
      attr_reader :dependencies
      attr_reader :system
      attr_reader :source_map

      def initialize(system, path)
        @order = Float::INFINITY
        @system = system
        @path = path
        @dependants = Set.new
        @dependencies = Set.new
        @state = :dirty
        @system.register(@path, self)
        @source = nil
        @source_map = nil
        @assets = Set.new
      end

      def assets = @assets.to_a

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
          @state,
          @source,
          @assets,
          @source_map
        ]
      end

      def marshal_load(a)
        @order,
        @path,
        @dependants,
        @dependencies,
        @state,
        @source,
        @assets,
        @source_map =
          a
        Registry[@path] = self
      end

      def reload(reload_source: true)
        if const_defined?(:Exports)
          puts "Reloading #{@path}"
          old_exports = const_get(:Exports)
          remove_const(:Exports)
        else
          Console.logger.info(self, "Loading #{@path}")
        end

        if reload_source
          begin
            reload_source!
          rescue => e
            const_set(:Exports, old_exports) if old_exports
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
            Exports.new(self, "", path)
          end

        const_set(:Exports, exports)
      ensure
        @dirty = false
      end

      def reload_source!
        @source, @source_map = @system.read_source(@path)
      end

      def dirty? = @dirty
      def dirty! = @dirty = true

      def import(path)
        @system.import(path, @path)
      end

      def add_asset(asset)
        @assets.add(asset)
        @system.add_asset(asset, @path)
      end

      def exports
        self::Exports.constants
      end

      def absolute_path
        File.join(@system.root, @path)
      end
    end
  end
end
