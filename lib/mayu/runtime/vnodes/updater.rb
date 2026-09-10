# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"

require_relative "command_collector"
require_relative "../commands"

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
                work_items = [@queue.dequeue]
                work_items << @queue.dequeue until @queue.empty?

                command_collector = CommandCollector.new
                navigations = []
                synchronizations = []
                updates = {}

                work_items.each do |item|
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
                      node.update(command_collector, descriptor)
                    else
                      node.update(command_collector)
                    end
                  rescue VComponent::UnhandledRenderError => e
                    @engine&.root&.emit_render_error(
                      command_collector,
                      e.error,
                      e.component
                    )
                  end
                end

                navigations.each do |nav|
                  if nav.push_state
                    command_collector << Commands::HistoryPushState[nav.path]
                  end
                end

                history_commands = []
                if navigations.any?
                  history_commands =
                    command_collector.commands.select do |command|
                      command.is_a?(Commands::HistoryPushState)
                    end
                  command_collector.commands.reject! do |command|
                    command.is_a?(Commands::HistoryPushState)
                  end
                end

                head_commands = []
                if @engine&.head_dirty?
                  head_collector = CommandCollector.new
                  @engine.flush_head(head_collector)
                  head_commands = head_collector.commands
                end
                @engine&.flush_dirty_elements(command_collector)

                commands = command_collector.commands
                commands = history_commands + head_commands + commands
                unless commands.empty?
                  if updates.keys.any? { |node|
                       node.instance_variable_get(:@__view_transition_pending)
                     }
                    updates.keys.each do |node|
                      node.instance_variable_set(
                        :@__view_transition_pending,
                        nil
                      )
                    end
                    @engine.enqueue_batch(
                      Batch[
                        [Commands::ViewTransition[Batch[commands]]]
                      ]
                    )
                  else
                    @engine.enqueue_batch(Batch[commands])
                  end
                end

                synchronizations.each do |synchronization|
                  @engine.enqueue_batch(
                    Batch[[], completion: synchronization.completion]
                  )
                end

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
