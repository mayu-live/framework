# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
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

    def self.run(system, task: Async::Task.current, &)
      require "listen"

      queue = Async::Queue.new

      watcher =
        task.async do |subtask|
          listener =
            Listen.to(system.root) do |updated, created, deleted|
              subtask.async do
                queue.enqueue(
                  [
                    updated.map do
                      Events::Updated[it.delete_prefix(system.root)]
                    end,
                    created.map do
                      Events::Created[it.delete_prefix(system.root)]
                    end,
                    deleted.map do
                      Events::Deleted[it.delete_prefix(system.root)]
                    end
                  ].flatten
                )
              end
            end

          Console.logger.info(self, "Starting watcher")
          listener.start
          sleep
        rescue => e
          Console.logger.error(self, e)
          raise
        ensure
          Console.logger.info(self, "Stopping watcher")
          listener&.stop
        end

      loop { yield queue.dequeue }
    ensure
      watcher.stop
    end
  end
end
