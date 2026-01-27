# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"

require_relative "patcher"

module Mayu
  module Runtime
    module VNodes2
      class Updater
        attr_reader :queue, :task, :output_queue

        def initialize(output_queue)
          @queue = Async::Queue.new
          @output_queue = output_queue
          @task = nil
        end

        def start(parent_task: Async::Task.current)
          @task =
            parent_task.async do
              loop do
                vnode = @queue.dequeue
                batch = [vnode]
                batch << @queue.dequeue until @queue.empty?

                patcher = Patcher.new
                batch.uniq.each { |node| node.update(patcher) }

                @output_queue.enqueue(patcher.patches)
              end
            end
        end

        def stop
          @task&.stop
          @task = nil
        end

        def enqueue(vnode)
          @queue.enqueue(vnode)
        end
      end
    end
  end
end
