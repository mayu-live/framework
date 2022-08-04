# typed: strict

require_relative "vdom"
require_relative "vdom/vtree"
require_relative "vdom/component"
require_relative "modules/system"
require_relative "routes"
require_relative "state/store"

module Mayu
  class Renderer
    extend T::Sig

    sig { params(environment: Environment, request_path: String, parent: T.any(Async::Task, Async::Barrier)).void }
    def initialize(environment:, request_path:, parent: Async::Task.current)
      # We should match the route earlier, so that we don't have to get this
      # far in case it doesn't match...
      route_match = environment.match_route(request_path)

      # Load the page component.
      page_component = environment.modules.load_page(route_match.template).klass

      # Apply the layouts.
      app = route_match.layouts.reverse.reduce(VDOM.h(page_component)) do |app, layout|
        layout_component = environment.modules.load_page(layout).klass
        VDOM.h(layout_component, {}, [app])
      end

      # Store the root of the application.
      # If we change the URL, we should find a new page component
      # for that path, replace @root and rerender.
      # Same thing if a file is reloaded...
      # Also, for reloading we need to keep track of which components import
      # other compoents, because we need to replace the constants in their
      # classes...
      @root = T.let(app, VDOM::Descriptor)

      # Set up a barrier to group async tasks together.
      @barrier = T.let(Async::Barrier.new(parent:), Async::Barrier)

      # Create the store.
      # In the future we could initialize the state with something already
      # stored somewhere. But for now we start with an empty state.
      store = environment.create_store(initial_state: {})

      @vtree = T.let(VDOM::VTree.new(store: store, task: @barrier), VDOM::VTree)

      @barrier.async(annotation: "Renderer patch sets") do
        @vtree.on_update.wait => :patch, initial_patches
        initial_insert = initial_patches.find { _1[:type] == :insert }

        unless initial_insert
          raise "No insert patch in initial render!"
        end

        respond(:initial_render, initial_patches)
        respond(:init, initial_insert[:ids])

        loop do
          message = @vtree.on_update.wait

          case message
          in :patch, patches
            respond(:patch, patches)
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

    sig { params(args: T.untyped).void }
    def respond(*args) = @out.enqueue(args)

    sig {void}
    def rerender! = @vtree.render(@root)
  end
end
