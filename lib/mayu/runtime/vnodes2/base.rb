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
        attr_reader :id
        attr_reader :descriptor
        attr_reader :parent

        def initialize(descriptor, parent:)
          @descriptor = descriptor
          @parent = parent
          @id = SecureRandom.alphanumeric
        end

        def task = @task || parent.task

        def marshal_dump
          [@id, @id_counter, @descriptor, @parent]
        end

        def marshal_load(a)
          @id, @id_counter, @descriptor, @parent = a
        end

        def metrics
          @metrics ||= @parent.metrics
        end

        def ancestor_info
          @parent.ancestor_info
        end

        def running?
          !!@updater
        end

        def patch(updater)
        end

        def start_children
        end

        def apply(descriptor)
          @updater ? @updater.enqueue(descriptor) : update(descriptor)
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
        end

        def start_children
        end

        def stop
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
