# frozen_string_literal: true
# typed: strict

require_relative "hot_swap/file_watcher"
require_relative "registry"

module Mayu
  module Resources
    module HotSwap
      extend T::Sig

      sig do
        params(registry: Registry, block: T.proc.void).returns(Async::Task)
      end
      def self.start(registry, &block)
        FileWatcher.watch(registry.root, ["app"]) do |event|
          Console.logger.info(self, "\e[33mSwapping code\e[0m")
          start_at = Time.now.to_f

          visited = T::Set[String].new

          event.modified.each do |path|
            registry.reload_resource(path, visited:)
          end

          event.added.each do |path|
            registry.reload_resource(
              path,
              visited:,
              add: path.start_with?("/app/pages/")
            )
          end

          event.removed.each { |path| registry.unload_resource(path, visited:) }

          Console.logger.info(
            self,
            format("\e[33mSwapped code in %.3fs\e[0m", Time.now.to_f - start_at)
          )

          yield
        end
      end
    end
  end
end
