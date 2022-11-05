# frozen_string_literal: true
# typed: strict

module Mayu
  module Resources
    class Assets
      extend T::Sig

      sig { void }
      def initialize
        @queue = T.let(Async::Queue.new, Async::Queue)
        @results = T.let({}, T::Hash[String, Async::Variable])
        @assets = T.let({}, T::Hash[String, Asset])
      end

      sig { params(filename: String).void }
      def wait_for(filename)
        (@results[filename] ||= Async::Variable.new).wait
      end

      sig { params(asset: Asset).void }
      def add(asset)
        @assets[asset.filename] ||= asset
        @queue.enqueue(asset)
      end

      sig do
        params(
          asset_dir: String,
          concurrency: Integer,
          task: Async::Task
        ).returns(Async::Task)
      end
      def run(asset_dir, concurrency: 4, task: Async::Task.current)
        task.async do
          loop do
            asset = @queue.dequeue

            if asset.process(asset_dir)
              var = (@results[asset.filename] ||= Async::Variable.new)
              var.resolve unless var.resolved?
            end
          rescue => e
            Console.logger.error(self, e)
            raise
          end
        end
      end
    end
  end
end
