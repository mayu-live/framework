# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"

require_relative "vnodes2/engine"

module Mayu
  module Runtime
    class Engine
      attr_reader :runtime_js
      attr_accessor :metrics

      def initialize(descriptor, metrics:, runtime_js:)
        @metrics = metrics
        @runtime_js = runtime_js
        @engine =
          VNodes2::Engine.new(descriptor, metrics:, runtime_js: runtime_js)
      end

      def marshal_dump
        [@runtime_js, @engine]
      end

      def marshal_load(a)
        @runtime_js, @engine = a
      end

      def patch(patches)
        @engine.patch(patches)
      end

      def callback(id, payload)
        @engine.callback(id, payload)
      end

      def navigate(path, descriptor, push_state: true)
        @engine.navigate(path, descriptor, push_state:)
      end

      def ping(timestamp)
        @engine.ping(timestamp)
      end

      def update(descriptor)
        @engine.update(descriptor)
      end

      def render
        @engine.render
      end

      def dom_id_tree
        @engine.dom_id_tree
      end

      def styles
        @engine.styles
      end

      def start
        @engine.start
      end

      def stop
        @engine.stop
      end

      def dequeue_patch
        @engine.dequeue_patch
      end

      private
    end
  end
end
