# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    module Watcher
      module Events
        Created =
          Data.define(:path) do
            def to_s = "\e[32m#{self.class.name}[#{path.inspect}]\e[0m"
          end

        Deleted =
          Data.define(:path) do
            def to_s = "\e[31m#{self.class.name}[#{path.inspect}]\e[0m"
          end

        Updated =
          Data.define(:path) do
            def to_s = "\e[33m#{self.class.name}[#{path.inspect}]\e[0m"
          end

        def self.from_sym(event)
          case event
          in :created
            Created
          in :updated
            Updated
          in :deleted
            Deleted
          end
        end

        def self.build(event, path)
          from_sym(event).new(path)
        end
      end

      def self.run(system, task:, &)
        require "filewatcher"

        Filewatcher.class_eval do
          # Filewatcher traps signals we need
          def trap(_signal) = nil
        end

        queue = Async::Queue.new

        watcher = task.async do
          fw = Filewatcher.new([system.root])
          fw.watch do |changes|
            queue.enqueue(
              changes.map do |path, event|
                Events.build(event, system.relative_from_root(path))
              end
            )
          end
        ensure
          fw.stop
        end

        loop do
          yield queue.dequeue
        end
      ensure
        watcher.stop
      end
    end
  end
end
