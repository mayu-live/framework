require "async/queue"

require_relative "vnodes"

module Mayu
  module Runtime
    class Engine
      attr_reader :runtime_js

      def initialize(descriptor, runtime_js:)
        @patches = Async::Queue.new
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
        Array(patches).flatten.each do |patch|
          @patches.enqueue(patch)
        end
      end

      def callback(id, payload)
        @root.call_listener(id, payload)
      end

      def navigate(path, descriptor, push_state: true)
        update(descriptor)

        if push_state
          @patches.enqueue(Patches::HistoryPushState[path])
        end
      end

      def ping(timestamp)
        @patches.enqueue(Patches::Pong[timestamp])
      end

      def update(descriptor)
        @root.update(descriptor)
      end

      def render
        @root.render
      end

      def stop
        @root.stop
      end

      def run(&)
        @root.start

        loop do
          if patch = @patches.dequeue
            yield patch
          end
        end
      ensure
        puts "\e[31mSTOPPING ROOT\e[0m"
        @root.stop
      end
    end
  end
end
