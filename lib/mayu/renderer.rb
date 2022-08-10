# typed: strict

require_relative "vdom"
require_relative "vdom/vtree"
require_relative "vdom/component"
require_relative "modules/system"
require_relative "routes"
require_relative "session"

module Mayu
  class Renderer
    extend T::Sig

    sig do
      params(
        environment: Environment,
        request_path: String,
        parent: T.any(Async::Task, Async::Barrier)
      ).void
    end
    def initialize(environment:, request_path:, parent: Async::Task.current)
      @environment = environment
      @session = T.let(Session.new(environment, request_path:), Session)

      # Set up a barrier to group async tasks together.
      @barrier = T.let(Async::Barrier.new(parent:), Async::Barrier)

      @vtree =
        T.let(
          VDOM::VTree.new(
            store: @session.store,
            fetch: @session.fetch,
            task: @barrier
          ),
          VDOM::VTree
        )

      if code_reloader = environment.modules.code_reloader
        @barrier.async do
          code_reloader.on_update { navigate(@session.current_path) }
        end
      end

      @barrier.async(annotation: "Renderer patch sets") do
        @vtree.on_update.dequeue => [:patch, initial_patches]
        initial_insert = initial_patches.find { _1[:type] == :insert }

        raise "No insert patch in initial render!" unless initial_insert

        respond(:initial_render, initial_patches)
        respond(:init, initial_insert[:ids])

        loop do
          message = @vtree.on_update.dequeue

          case message
          in [:patch, patches]
            respond(:patch, patches)
          in [:exception, error]
            respond(:exception, error)
          in [:navigate, href]
            navigate(href)
            respond(:navigate, href)
          else
            puts "\e[31mUnknown event: #{message.inspect}\e[0m"
          end
        end
      end

      @in = T.let(Async::Queue.new, Async::Queue)
      @out = T.let(Async::Queue.new, Async::Queue)

      @barrier.async(annotation: "Renderer event handlers") do
        loop do
          message = @in.dequeue

          case message
          in :render
            rerender!
          in [:handle_callback, callback_id, payload]
            @vtree.handle_event(callback_id, payload)
          else
            puts "Invalid message: #{message.inspect}"
          end
        end
      end

      rerender!
    end

    sig { params(callback_id: String, payload: T.untyped).returns(T::Boolean) }
    def handle_callback(callback_id, payload = {})
      send(:handle_callback, callback_id, payload)
      true
    end

    sig { returns(T::Boolean) }
    def running? = @barrier.empty?

    sig { void }
    def stop
      @vtree.stop!
      @barrier.stop
    end

    sig { params(args: T.untyped).void }
    def send(*args) = @in.enqueue(args)
    sig { returns(T.untyped) }
    def take
      @out.dequeue
    end

    sig { returns(T.untyped) }
    def id_tree = @vtree.id_tree

    private

    sig { params(path: String).void }
    def navigate(path)
      @session.navigate(path)
      rerender!
    end

    sig { params(args: T.untyped).void }
    def respond(*args) = @out.enqueue(args)

    sig { void }
    def rerender! = @vtree.render(@session.app)
  end
end
