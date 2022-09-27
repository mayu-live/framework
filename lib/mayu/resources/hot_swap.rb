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
          Console
            .logger
            .measure(self, "\e[33mSwapping code\e[0m") do
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

              event.removed.each do |path|
                registry.unload_resource(path, visited:)
              end
            end

          yield
        end
      end
    end
  end
end
