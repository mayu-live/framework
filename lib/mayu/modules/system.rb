# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "pathname"
require "tsort"

require_relative "mod"
require_relative "rules"
require_relative "resolver"
require_relative "registry"
require_relative "loaders"
require_relative "assets"
require_relative "watcher"
require_relative "import"
require_relative "generators"

module Mayu
  module Modules
    class System
      CURRENT_KEY = :modules_system

      def self.use(root, **options, &)
        new(root, **options).use(&)
      end

      def self.current = Fiber[CURRENT_KEY]

      def self.import(path, source) = current.import(path, source)

      def self.add_asset(generator) = current.add_asset(generator)

      def self.import?(path, source)
        import(path, source)
      rescue StandardError
        nil
      end

      attr_reader :root

      def initialize(root, rules: [], extensions: ["", ".rb"])
        @root = File.expand_path(root)
        @resolver = Resolver.new(@root, extensions:)
        @rules = rules
        @assets = Assets::Storage.new
        @on_reload = Async::Notification.new
        @mods = {}
      end

      def wait_for_reload
        @on_reload.wait
      end

      def marshal_dump
        [@root, @resolver, @rules, @assets, Marshal.dump(@mods)]
      end

      def marshal_load(a)
        @root, @resolver, @rules, @assets, mods = a
        @on_reload = Async::Notification.new

        use do
          @mods = Marshal.load(mods)
          @mods
            .each_value { _1.instance_variable_set(:@system, self) }
            .each_value { _1.reload(reload_source: false) }
        end
      end

      def use(&)
        prev = Fiber[CURRENT_KEY]
        Fiber[CURRENT_KEY] = self
        yield self
      ensure
        Fiber[CURRENT_KEY] = prev
      end

      def read_source(path)
        file = Loaders::LoadingFile[@root, path, nil].load_source
        input = file.source

        matching_rules = @rules.select { _1.match?(path) }

        raise "No rules for file: #{path}" if matching_rules.empty?

        transformed =
          matching_rules.reduce(file) { |file, rule| rule.call(file) }.source
        # .tap do
        #   puts "\e[3m#{path}\e[0m\e[35m\n#{_1}\e[0m"
        # end

        source_map = SourceMap::SourceMap.parse(input, transformed)
        [transformed, source_map]
      end

      def relative_from_root(path)
        Pathname.new(path).relative_path_from(@root).to_s.sub(%r{\A/*}, "/")
      end

      def register(path, mod)
        Registry[path] = mod
        @mods[path] = mod
      end

      def unregister(path)
        @mods.each do |mod|
          mod.dependants.delete(path)
          mod.dependencies.delete(path)
        end

        Registry.delete(path)
        @mods.delete(path)
      end

      def start_watch(task: Async::Task.current)
        task.async do
          Watcher.run(self, task:) do |events|
            events.each do |event|
              puts event.to_s

              case event
              in Watcher::Events::Created[path:]
              in Watcher::Events::Updated[path:]
                if mod = @mods[path]
                  mod.dirty!
                  visit_dependants(mod, &:dirty!)
                else
                  puts "\e[31mModule not found: #{path}\e[0m"
                end
              in Watcher::Events::Deleted[path:]
                if mod = @mods.delete(path)
                  visit_dependants(mod, &:dirty?)
                  delete_mod(path)
                end
              end
            end

            reload_dirty
          end
        end
      end

      def import(path, source = "/")
        # puts "\e[35mimport(#{path.inspect}, #{source.inspect})\e[0m"

        mod = get_or_load_mod(path, File.dirname(source))

        if source_mod = @mods[source]
          mod.dependants.add(source_mod.path)
          source_mod.dependencies.add(mod.path)
        end

        mod::Exports::Default
      end

      def delete(path)
        # TODO: Implement me
        @mods[source]
      end

      def add_asset(asset)
        @assets.enqueue(asset)
      end

      def overall_order
        TSort.tsort(
          ->(&b) { @mods.keys.each(&b) },
          ->(key, &b) { @mods[key]&.dependants&.each(&b) }
        )
      end

      def update_order
        overall_order.each_with_index { |mod, index| mod.order = index }
      end

      def delete_mod(id)
        return unless @mods.include?(id)

        @mods.each do |mod|
          mod.dependencies.delete(id)
          mod.dependants.delete(id)
        end
      end

      def get_mod(path, source = "/")
        @mods[@resolver.resolve(path, source)]
      end

      def get_asset(filename)
        @assets.get(filename)
      end

      def wait_for_asset(filename)
        @assets.wait_for(filename)
      end

      def process_assets(out_dir:, concurrency: 2, forever: false)
        @assets.run(out_dir, concurrency:, forever:)
      end

      private

      def reload_dirty
        overall_order
          .reverse
          .map { @mods[_1] }
          .compact
          .select(&:dirty?)
          .each(&:reload)
        @on_reload.signal(true)
      end

      def get_or_load_mod(path, source = "/")
        resolved_path = @resolver.resolve(path, source)

        if mod = @mods[resolved_path]
          mod
        else
          mod = Mod.new(self, resolved_path)
          @mods[resolved_path] = mod
          mod.reload
          mod
        end
      end

      def visit_dependants(mod, &block)
        mod.dependants.each do |dependency|
          if mod = @mods[dependency]
            yield mod
            visit_dependants(mod, &block)
          end
        end
      end
    end
  end
end
