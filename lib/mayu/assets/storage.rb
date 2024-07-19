# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "mime/types"
require "digest/sha2"
require "async/queue"
require "async/variable"
require "async/semaphore"

module Mayu
  module Assets
    class Storage
      Static =
        Data.define(:assets) do
          def get(filename)
            assets[filename]
          end

          def wait_for(filename)
            get(filename)
          end

          def enqueue(_generator)
          end
        end

      def initialize
        @assets = {}
        @results = {}
        @queue = Async::Queue.new
      end

      def get(filename)
        @assets[filename]
      end

      def wait_for(filename)
        @assets.fetch(filename) do
          (@results[filename] ||= Async::Variable.new).wait
        end
      end

      def enqueue(generator)
        @queue.enqueue(generator)
      end

      def all_processed?
        @queue.empty?
      end

      def run(
        assets_dir,
        forever: false,
        concurrency: 1,
        task: Async::Task.current
      )
        task.async do
          semaphore = Async::Semaphore.new(concurrency)

          while forever || !@queue.empty?
            generator = @queue.dequeue
            semaphore.async { process(generator, assets_dir) }
          end
        end
      end

      def _dump(_level)
        Marshal.dump(@assets)
      end

      def self._load(data)
        Static[Marshal.load(data)]
      end

      private

      def process(generator, assets_dir)
        if asset = generator.process(assets_dir)
          @assets.store(asset.filename, asset)
          var = (@results[asset.filename] ||= Async::Variable.new)
          var.resolve(asset) unless var.resolved?
          @results.delete(asset.filename)
        end
      rescue => e
        Console.logger.error(self, e)
        raise e
      end
    end
  end
end
