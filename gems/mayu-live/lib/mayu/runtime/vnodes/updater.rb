# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "async/queue"

require_relative "command_collector"
require_relative "../commands"

module Mayu
  module Runtime
    module VNodes
      class Updater
        Navigation = Data.define(:id)
        Synchronization = Data.define(:completion)
        # A command that must reach the client after the DOM updates queued
        # before it, such as a browser action from a callback.
        Command = Data.define(:command)

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

                process(work_items)

                # Work queued during the pause is coalesced into the next pass.
                if (interval = @engine&.update_interval)
                  Async::Task.current.sleep(interval)
                end

                Fiber.scheduler.yield
              end
            end
        end

        def stop
          @task&.stop
          @task = nil
        end

        # Processes queued work in the current fiber until the queue is
        # empty, including chunks that paused updates enqueue for later.
        # Used after #stop, so that the browser receives every update
        # before the session state is serialized.
        def drain
          until @queue.empty?
            work_items = []
            work_items << @queue.dequeue until @queue.empty?
            process(work_items)
          end
        end

        def enqueue(vnode)
          @queue.enqueue(vnode)
        end

        def synchronize
          synchronization = Synchronization[Async::Queue.new]
          @queue.enqueue(synchronization)
          synchronization.completion.dequeue
        end

        private

        def process(work_items)
          command_collector = CommandCollector.new
          navigations = []
          trailing_commands = []
          synchronizations = []
          updates = {}

          work_items.each do |item|
            if item.is_a?(Synchronization)
              synchronizations << item
            elsif item.is_a?(Navigation)
              navigations << item
            elsif item.is_a?(Command)
              trailing_commands << item.command
            else
              updates[item] ||= nil
            end
          end

          updates.each do |node, descriptor|
            next if node.removed?
            checkpoint = command_collector.checkpoint
            begin
              if descriptor
                node.update(command_collector, descriptor)
              else
                node.update(command_collector)
              end
            rescue VComponent::UnhandledRenderError => e
              @engine&.root&.resolve_render_error(
                command_collector,
                e,
                checkpoint
              )
            end
          end

          # Listener registration is committed only after every update in
          # this batch (including any error-boundary recovery) has settled.
          @engine&.root&.flush_listener_index!

          head_commands = []
          if @engine&.head_dirty?
            head_collector = CommandCollector.new
            @engine.flush_head(head_collector)
            head_commands = head_collector.commands
          end
          @engine&.flush_dirty_elements(command_collector)

          commands = command_collector.commands
          navigation_id = navigations.last&.id
          navigation_completion = nil
          if navigation_id
            navigation_completion = Commands::NavigationComplete[navigation_id]
          end
          transition_nodes =
            updates.keys.select do |node|
              !node.instance_variable_get(:@__view_transition_pending).nil?
            end

          if transition_nodes.any?
            # A head update can replace the stylesheet that styles the
            # transition pseudo-elements. Apply it before the browser
            # captures the old state, rather than inside the callback.
            @engine.enqueue_batch(Batch[head_commands]) unless head_commands.empty?

            transitions =
              transition_nodes.map do |node|
                node.instance_variable_get(:@__view_transition_pending)
              end
            transition_types = transitions.flat_map { it[:types] }.uniq
            transition_scope = transitions.filter_map { it[:scope] }.first
            updates.keys.each do |node|
              node.instance_variable_set(:@__view_transition_pending, nil)
            end

            unless commands.empty?
              @engine.enqueue_batch(
                Batch[
                  [
                    Commands::ViewTransition[
                      Batch[commands],
                      transition_types,
                      transition_scope
                    ]
                  ]
                ]
              )
            end
            @engine.enqueue_command(navigation_completion) if navigation_completion
            @engine.enqueue_batch(Batch[trailing_commands]) unless trailing_commands.empty?
          else
            commands = head_commands + commands
            commands << navigation_completion if navigation_completion
            commands.concat(trailing_commands)
            @engine.enqueue_batch(Batch[commands]) unless commands.empty?
          end

          synchronizations.each do |synchronization|
            @engine.enqueue_batch(
              Batch[[], completion: synchronization.completion]
            )
          end
        end
      end
    end
  end
end
