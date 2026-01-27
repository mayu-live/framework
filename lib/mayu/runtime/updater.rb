# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"

require_relative "vnodes"

module Mayu
  module Runtime
    class UpdateQueue
      class Updater
        def initialize
          @patches = []
        end

        def <<(patch)
          @patches << patch
        end

        attr_reader :patches
      end

      def initialize
        @queue = Async::Queue.new
      end

      def run(parent: Async::Task.current)
        parent.async do |task|
          loop do
            @queue.wait while @queue.empty?

            updater = Updater.new

            @queue.size.times do
              case @queue.dequeue
              in VNodes::Base => vnode
                vnode.handle_update(updater)
              end
            end
          end
        end
      end
    end
  end
end
