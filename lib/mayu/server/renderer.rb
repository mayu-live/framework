# typed: strict

require "async/task"
require "async/queue"

module Mayu
  module Server
    class Renderer
      extend T::Sig

      State = T.type_alias { T::Hash[Symbol, T.untyped] }
      InitialHtmlAndState = T.type_alias { { html: String, state: State } }

      sig { returns(State) }
      attr_reader :state

      sig { params(state: T.nilable(State)).void }
      def initialize(state: {})
        @state =
          T.let({ time: Time.now.to_s, count: 0 }.merge(state || {}), State)
        @messages = T.let(Async::Queue.new, Async::Queue)
      end

      sig { returns(InitialHtmlAndState) }
      def initial_html_and_state
        html = File.read(File.join(__dir__, "page.html"))
        { html:, state: }
      end

      sig do
        params(
          task: Async::Task,
          block: T.proc.params(arg0: State).void
        ).returns(Async::Task)
      end
      def run(task: Async::Task.current, &block)
        task.async do
          loop do
            sleep 1
            @state[:count] += 1
            @state[:time] = Time.now.to_s
            @messages.enqueue(@state.dup)
          end
        end

        task.async { loop { yield @messages.dequeue } }
      end
    end
  end
end
