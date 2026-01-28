# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"
require "set"

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
          @dirty_elements = Set.new
          @root = VDocument.new(descriptor, parent: nil, engine: self)
        end

        def marshal_dump
          [@runtime_js, @root]
        end

        def marshal_load(a)
          @runtime_js, @root = a
          @output_queue = Async::Queue.new
          @updater = Updater.new(@output_queue)
          @dirty_elements = Set.new
          @root.rehydrate(parent: nil, engine: self)
        end

        def dump
          Marshal.dump(self)
        end

        def dump!
          stop
          dump
        end

        def self.restore(data)
          Marshal.load(data)
        end

        def self.restore!(data)
          engine = restore(data)
          engine.start
          engine
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
          @task&.stop
        end

        def enqueue_update(vnode)
          @updater.enqueue(vnode)
        end

        def callback(id, payload)
          @root.call_listener(id, payload)
        end

        def flush_head(patcher)
          @root.flush_head(patcher)
        end

        def register_dirty_element(element)
          @dirty_elements.add(element)
        end

        def flush_dirty_elements(patcher)
          return if @dirty_elements.empty?
          @dirty_elements.each do |element|
            element.emit_replace_children(patcher)
          end
          @dirty_elements.clear
        end

        def dequeue_patches
          @output_queue.dequeue
        end
      end
    end
  end
end
