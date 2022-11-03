# frozen_string_literal: true
# typed: strict

module Mayu
  module Resources
    class Assets
      extend T::Sig

      sig { params(concurrency: Integer).void }
      def initialize(concurrency: 4)
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

      sig { params(task: Async::Task).void }
      def process(task: Async::Task.current)
        task.async { loop { @queue.dequeue.process } }
      end
    end
  end
end
