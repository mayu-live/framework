# typed: strict

require "sorbet-runtime"
require "listen"
require "async"
require "async/queue"
require "thread"

module Mayu
  module Resources
    module FileWatcher
      extend T::Sig

      class Event < T::Struct
        const :modified, T::Array[String]
        const :added, T::Array[String]
        const :removed, T::Array[String]
      end

      sig do
        params(
          dir: String,
          task: Async::Task,
          block: T.proc.params(arg0: Event).void
        ).returns(Async::Task)
      end
      def self.watch(dir = Dir.pwd, task: Async::Task.current, &block)
        dir = File.expand_path(dir)

        queue = Thread::Queue.new

        listener =
          T.let(
            Listen.to(dir) do |modified, added, removed|
              Event
                .new(
                  modified: modified.map { _1.delete_prefix(dir) },
                  added: added.map { _1.delete_prefix(dir) },
                  removed: removed.map { _1.delete_prefix(dir) }
                )
                .then { queue.enq(_1) }
            end,
            Listen::Listener
          )

        listener.start

        task.async do
          loop { block.call(queue.deq) }
        ensure
          listener.stop
        end
      end
    end
  end
end

# Async do
#   Mayu::Resources::FileWatcher.watch(File.join(Dir.pwd, "example2")) do |event|
#     p event
#   end
# end
