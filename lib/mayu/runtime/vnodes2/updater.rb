# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"

require_relative "patcher"
require_relative "../patches"

module Mayu
  module Runtime
    module VNodes2
      class Updater
        attr_reader :queue, :task, :output_queue

        def initialize(output_queue)
          @queue = Async::Queue.new
          @output_queue = output_queue
          @task = nil
          @engine = nil
        end

        def start(parent_task: Async::Task.current, engine: nil)
          @engine = engine
          @task =
            parent_task.async do
              loop do
                vnode = @queue.dequeue
                batch = [vnode]
                batch << @queue.dequeue until @queue.empty?

                patcher = Patcher.new
                unique = batch.uniq
                unique.each { |node| node.update(patcher) }
                @engine&.flush_dirty_elements(patcher)
                @engine&.flush_head(patcher)

                if unique.any? { |node|
                     node.instance_variable_get(:@__view_transition_pending)
                   }
                  unique.each do |node|
                    node.instance_variable_set(:@__view_transition_pending, nil)
                  end
                  @output_queue.enqueue(
                    [Patches::ViewTransition[patcher.patches]]
                  )
                else
                  @output_queue.enqueue(patcher.patches)
                end
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
