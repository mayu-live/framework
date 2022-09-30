# frozen_string_literal: true
# typed: strict

require "listen"
require "async"
require "async/queue"
require "async/task"
require "thread"

module Mayu
  module Resources
    module HotSwap
      module FileWatcher
        extend T::Sig

        class Event < T::Struct
          const :modified, T::Array[String]
          const :added, T::Array[String]
          const :removed, T::Array[String]
        end

        sig do
          params(
            root: String,
            dirs: T::Array[String],
            task: Async::Task,
            block: T.proc.params(arg0: Event).void
          ).returns(Async::Task)
        end
        def self.watch(
          root = Dir.pwd,
          dirs = [""],
          task: Async::Task.current,
          &block
        )
          root = File.expand_path(root)
          queue = Thread::Queue.new
          paths = dirs.map { File.join(root, _1) }

          listener =
            T.let(
              T
                .unsafe(Listen)
                .to(*paths) do |modified, added, removed|
                  Event
                    .new(
                      modified: modified.map { _1.delete_prefix(root) },
                      added: added.map { _1.delete_prefix(root) },
                      removed: removed.map { _1.delete_prefix(root) }
                    )
                    .then { queue.enq(_1) }
                end,
              Listen::Listener
            )

          listener.start

          Console.logger.info("Watching directories for changes:", *paths)

          task.async do
            loop { block.call(queue.deq) }
          ensure
            listener.stop
          end
        end
      end
    end
  end
end
