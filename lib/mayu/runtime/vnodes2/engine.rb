# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"

require_relative "vdocument"
require_relative "updater"

module Mayu
  module Runtime
    module VNodes2
      class Engine
        attr_reader :runtime_js, :root, :output_queue

        def initialize(descriptor, runtime_js: nil)
          @runtime_js = runtime_js
          @output_queue = Async::Queue.new
          @updater = Updater.new(@output_queue)
          @root = VDocument.new(descriptor, parent: nil, engine: self)
        end

        def task
          @updater.task
        end

        def start
          @updater.start(engine: self)
          @root.start
        end

        def stop
          @root.stop
          @updater.stop
        end

        def enqueue_update(vnode)
          @updater.enqueue(vnode)
        end

        def flush_head(patcher)
          @root.flush_head(patcher)
        end

        def dequeue_patches
          @output_queue.dequeue
        end
      end
    end
  end
end
