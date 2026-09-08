# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"

require_relative "patcher"
require_relative "../patches"

module Mayu
  module Runtime
    module VNodes
      class Updater
        Navigation = Data.define(:path, :descriptor, :push_state)
        Synchronization = Data.define(:completion)

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
                batch = [@queue.dequeue]
                batch << @queue.dequeue until @queue.empty?

                patcher = Patcher.new
                navigations = []
                synchronizations = []
                updates = {}

                batch.each do |item|
                  if item.is_a?(Synchronization)
                    synchronizations << item
                  elsif item.is_a?(Navigation)
                    navigations << item
                  else
                    updates[item] ||= nil
                  end
                end

                updates.each do |node, descriptor|
                  next if node.removed?
                  begin
                    if descriptor
                      node.update(patcher, descriptor)
                    else
                      node.update(patcher)
                    end
                  rescue VComponent::UnhandledRenderError => e
                    @engine&.root&.emit_render_error(
                      patcher,
                      e.error,
                      e.component
                    )
                  end
                end

                navigations.each do |nav|
                  if nav.push_state
                    patcher << Patches::HistoryPushState[nav.path]
                  end
                end

                history_patches = []
                if navigations.any?
                  history_patches =
                    patcher.patches.select do |patch|
                      patch.is_a?(Patches::HistoryPushState)
                    end
                  patcher.patches.reject! do |patch|
                    patch.is_a?(Patches::HistoryPushState)
                  end
                end

                head_patches = []
                if @engine&.head_dirty?
                  head_patcher = Patcher.new
                  @engine.flush_head(head_patcher)
                  head_patches = head_patcher.patches
                end
                @engine&.flush_dirty_elements(patcher)

                patches = patcher.patches
                patches = history_patches + head_patches + patches
                unless patches.empty?
                  if updates.keys.any? { |node|
                       node.instance_variable_get(:@__view_transition_pending)
                     }
                    updates.keys.each do |node|
                      node.instance_variable_set(
                        :@__view_transition_pending,
                        nil
                      )
                    end
                    @output_queue.enqueue(
                      Patches::ViewTransition[Patches::Batch[patches]]
                    )
                  else
                    @output_queue.enqueue(Patches::Batch[patches])
                  end
                end

                synchronizations.each { @output_queue.enqueue(it) }

                Fiber.scheduler.yield
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

        def synchronize
          synchronization = Synchronization[Async::Queue.new]
          @queue.enqueue(synchronization)
          synchronization.completion.dequeue
        end
      end
    end
  end
end
