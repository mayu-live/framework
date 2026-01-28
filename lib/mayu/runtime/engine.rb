# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"

require_relative "vnodes"

module Mayu
  module Runtime
    class Engine
      attr_reader :runtime_js
      attr_accessor :metrics

      def initialize(descriptor, metrics:, runtime_js:)
        @patches = Async::Queue.new
        @metrics = metrics
        @runtime_js = runtime_js
        @root = VNodes::VDocument.new(descriptor, parent: self)
      end

      def marshal_dump
        [@runtime_js, @root]
      end

      def marshal_load(a)
        @runtime_js, @root = a
        @patches = Async::Queue.new
      end

      def patch(patches)
        Array(patches).flatten.each { |patch| @patches.enqueue(patch) }
      end

      def callback(id, payload)
        @root.call_listener(id, payload)
      end

      def navigate(path, descriptor, push_state: true)
        update(descriptor)

        @patches.enqueue(Patches::HistoryPushState[path]) if push_state
      end

      def ping(timestamp)
        @patches.enqueue(Patches::Pong[timestamp])
      end

      def update(descriptor)
        @root.apply(descriptor)
      end

      def render
        @root.render
      end

      def dom_id_tree
        render.id_node
      end

      def styles
        @root.styles
      end

      def start
        clear_patches!
        @root.start
      end

      def stop
        @root.stop
      end

      def dequeue_patch
        @patches.dequeue
      end

      private

      def clear_patches!
        @patches.dequeue until @patches.empty?
      end
    end
  end
end
