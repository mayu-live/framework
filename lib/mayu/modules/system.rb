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
require_relative "import"
require_relative "dependency"
require_relative "import_rewriter"
require_relative "backtrace_rewriter"
require_relative "../assets"

module Mayu
  module Modules
    class System
      CURRENT_KEY = :modules_system
      ReloadFailure =
        Data.define(
          :file,
          :type,
          :message,
          :backtrace,
          :source,
          :line,
          :column
        ) { def success? = false }
      ReloadResult =
        Data.define(:changed_paths, :removed_paths, :errors) do
          def success? = errors.empty?
        end

      def self.current
        Thread.current.thread_variable_get(CURRENT_KEY)
      end

      def self.use(root, **, &)
        new(root, **).use(&)
      end

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
        @assets = Mayu::Assets::Storage.new
        @on_reload = Async::Notification.new
        @mods = {}
      end

      def use(&)
        if self.class.current
          raise "There is already an active #{self.class.name}"
        end

        begin
          Thread.current.thread_variable_set(CURRENT_KEY, self)
          yield self
        ensure
          Thread.current.thread_variable_set(CURRENT_KEY, nil)
        end
      end

      def wait_for_reload
        @on_reload.wait
      end

      def marshal_dump
        [@root, @resolver, @assets, @mods]
      end

      def marshal_load(a)
        use do
          @root, @resolver, @assets, @mods = a
          @rules = []
          @on_reload = Async::Notification.new

          @mods
            .each_value { _1.instance_variable_set(:@system, self) }
            .each_value { _1::Exports }
        end
      end

      def read_source(path)
        file = Loaders::LoadingFile[@root, path, nil].load_source
        input = file.source

        matching_rules = @rules.select { _1.match?(path) }

        raise "No rules for file: #{path}" if matching_rules.empty?

        transformed =
          matching_rules.reduce(file) { |file, rule| rule.call(file) }.source
        rewritten =
          ImportRewriter.new(resolver: @resolver, source_path: path).call(
            transformed
          )
        # .tap do
        #   puts "\e[3m#{path}\e[0m\e[35m\n#{_1}\e[0m"
        # end

        source_map = SourceMap::SourceMap.parse(input, rewritten.source)
        [rewritten.source, source_map, rewritten.imports]
      end

      def relative_from_root(path)
        Pathname.new(path).relative_path_from(@root).to_s.sub(%r{\A/*}, "/")
      end

      def register(path, mod)
        Registry[path] = mod
        @mods[path] = mod

        @mods.each_value do |other_mod|
          next if other_mod.equal?(mod)
          next unless other_mod.dependencies.include?(path)

          mod.dependants.add(other_mod.path)
        end
      end

      def unregister(path)
        @mods.each do |path, mod|
          mod.dependants.delete(path)
          mod.dependencies.delete(path)
        end

        Registry.delete(path)
        @mods.delete(path)
      end

      def handle_watch_events(events)
        dirty_paths = Set.new
        removed_paths = Set.new
        reload_failures = []

        events.each do |event|
          # puts event

          case event
          in Watcher::Events::Created[path:]
          in Watcher::Events::Updated[path:]
            next unless mod = @mods[path]

            changed =
              begin
                mod.stage_source_update!
              rescue => e
                reload_failures << build_reload_failure(path, e)
                false
              end

            next unless changed

            dirty_paths.add(mod.path)
            visit_dependants(mod) { dirty_paths.add(_1.path) }
          in Watcher::Events::Deleted[path:]
            if mod = @mods.delete(path)
              removed_paths.add(path)
              visit_dependants(mod) { dirty_paths.add(_1.path) }
              unregister(path)
            end
          end
        end

        unless reload_failures.empty?
          reload_failures.each { log_reload_error(_1) }
          @on_reload.signal(
            ReloadResult[[], removed_paths.to_a, reload_failures]
          )
          return
        end

        return if dirty_paths.empty?

        modules_to_reload =
          overall_order
            .select { dirty_paths.include?(_1) }
            .reverse
            .map { @mods[_1] }
            .compact

        messages = []

        unless modules_to_reload.empty?
          messages.push("\e[1;33mReloading modules:\e[0m", *modules_to_reload)
        end

        unless removed_paths.empty?
          messages.push("\e[1;31mRemoved modules:\e[0m", *removed_paths)
        end

        Console.logger.info(self, *messages) unless messages.empty?

        modules_to_reload.each(&:reload)

        update_overall_order

        @on_reload.signal(
          ReloadResult[modules_to_reload.map(&:path), removed_paths.to_a, []]
        )
      end

      def import(path, source = "/")
        # puts "\e[35mimport(#{path.inspect}, #{source.inspect})\e[0m"

        source_mod = @mods[source]

        if source_mod && import_hash?(path)
          path =
            source_mod
              .dependency_nodes
              .find { _1.import_hash == path }
              &.resolved_path ||
              source_mod
                .imports
                .fetch(path) do
                  raise Resolver::ResolveError,
                        "Could not resolve import hash #{path.inspect} from #{source.inspect}"
                end
        end

        mod = get_or_load_mod(path, File.dirname(source))

        if source_mod
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

      def update_overall_order
        overall_order
          .map { @mods[_1] }
          .compact
          .each_with_index { |mod, index| mod.order = index }
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

      def generate_assets(asset_dir, **opts)
        @assets.run(asset_dir, **opts)
      end

      def format_exception(e)
        BacktraceRewriter.new(@mods).format_exception(e)
      end

      def rewrite_backtrace(backtrace)
        BacktraceRewriter.new(@mods).rewrite(backtrace)
      end

      def format_reload_error(reload_failure)
        if reload_failure.line && reload_failure.column
          "Failed to reload #{reload_failure.file} (#{reload_failure.type}): #{reload_failure.message} at #{reload_failure.file}:#{reload_failure.line}:#{reload_failure.column}"
        elsif reload_failure.line
          "Failed to reload #{reload_failure.file} (#{reload_failure.type}): #{reload_failure.message} at #{reload_failure.file}:#{reload_failure.line}"
        else
          "Failed to reload #{reload_failure.file} (#{reload_failure.type}): #{reload_failure.message}"
        end
      end

      def log_reload_error(reload_failure)
        message = format_reload_error(reload_failure)

        defined?(Console) ? Console.logger.error(self, message) : warn(message)
      end

      def resolve_dependencies_for(mod, imports)
        mod.dependency_nodes.each do |dependency|
          mod.dependencies.delete(dependency.resolved_path)
          @mods[dependency.resolved_path]&.dependants&.delete(mod.path)
        end

        dependency_nodes =
          imports
            .map do |import_hash, resolved_path|
              Dependency.new(mod.path, import_hash, resolved_path)
            end
            .to_set

        dependency_nodes.each do |dependency|
          mod.dependencies.add(dependency.resolved_path)
          @mods[dependency.resolved_path]&.dependants&.add(mod.path)
        end

        dependency_nodes
      end

      private

      def build_reload_failure(path, error)
        line = error.respond_to?(:lineno) ? error.lineno : nil
        column = error.respond_to?(:column) ? error.column : nil
        source = read_raw_source(path)
        backtrace = normalize_reload_backtrace(error.backtrace)

        if line
          location = [path, line, column].compact.join(":")
          unless backtrace.any? { _1.start_with?("#{path}:#{line}") }
            backtrace.unshift(location)
          end
        end

        ReloadFailure[
          path,
          error.class.name,
          error.message,
          backtrace,
          source,
          line,
          column
        ]
      end

      def read_raw_source(path)
        relative_path = path.sub(%r{\A/+}, "")
        File.read(File.join(@root, relative_path))
      rescue StandardError
        ""
      end

      def normalize_reload_backtrace(backtrace)
        rewrite_backtrace(Array(backtrace)).map(&:to_s)
      rescue => e
        Array(backtrace).map(&:to_s) + [e.message]
      end

      def import_hash?(path)
        path.is_a?(String) && path.start_with?(ImportRewriter::PREFIX)
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
