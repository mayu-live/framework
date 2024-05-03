# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "securerandom"
require "async"
require "async/queue"

module Mayu
  module Runtime
    module VNodes
      class Base
        Updater =
          Data.define(:task, :queue, :vnode) do
            def self.for_vnode(vnode, parent_task: Async::Task.current)
              queue = Async::Queue.new

              task =
                parent_task.async do
                  vnode.start_children

                  while descriptor = queue.dequeue
                    vnode.update_sync(descriptor)
                  end
                end

              Updater.new(task, queue, vnode)
            end

            def async(&)
              task.async { |subtask| yield subtask }
            end

            def enqueue(descriptor)
              queue.dequeue until queue.empty?
              queue.enqueue(descriptor)
            end

            def stop = task.stop

            def _dump = nil
            def _load = nil
          end

        attr_reader :id
        attr_reader :descriptor
        attr_reader :parent

        def initialize(descriptor, parent:)
          @descriptor = descriptor
          @parent = parent
          @id = SecureRandom.alphanumeric
          @id_counter = 0
        end

        def marshal_dump
          [@id, @id_counter, @descriptor, @parent]
        end

        def marshal_load(a)
          @id, @id_counter, @descriptor, @parent = a
        end

        def ancestor_info
          @parent.ancestor_info
        end

        def running?
          !!@updater
        end

        def patch(patches)
          @parent.patch(patches)
        end

        def start_children
        end

        def update(descriptor)
          @updater ? @updater.enqueue(descriptor) : update_sync(descriptor)
        end

        def closest(type)
          if type === self
            self
          else
            @parent&.closest(type)
          end
        end

        def closest!(type)
          closest or raise "Could not find node type #{type}"
        end

        def start
          @updater = Updater.for_vnode(self)
        end

        def start_children
        end

        def stop
          updater, @updater = @updater, nil
          updater&.stop
        end

        def update_child_ids
          @parent.update_child_ids
        end

        def traverse(&)
          yield self
        end
      end
    end
  end
end
