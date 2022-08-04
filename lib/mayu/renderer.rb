# typed: strict

require_relative "vdom"
require_relative "vdom/vtree"
require_relative "vdom/component"
require_relative "modules/system"

module Mayu
  class Renderer
    extend T::Sig

    sig { params(parent: T.any(Async::Task, Async::Barrier)).void }
    def initialize(parent: Async::Task.current)
      @in = T.let(Async::Queue.new, Async::Queue)
      @out = T.let(Async::Queue.new, Async::Queue)
      @barrier = T.let(Async::Barrier.new(parent:), Async::Barrier)

      modules = Mayu::Modules::System.new(File.join(Dir.pwd, "example", "app"))

      app =
        T.let(
          modules.load_component("App").klass,
          T.class_of(Mayu::VDOM::Component::Base)
        )

      @root = T.let(VDOM.h(app), VDOM::Descriptor)
      @vtree = T.let(VDOM::VTree.new(task: @barrier), VDOM::VTree)

      @barrier.async(annotation: "Renderer patch sets") do
        @vtree.on_update.wait => :patch, initial_patches
        first_insert = initial_patches.find { _1[:type] == :insert }

        unless first_insert
          raise "No insert patch in initial render!"
        end

        respond(:initial_render, initial_patches)
        respond(:init, first_insert[:ids])

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

      @barrier.async(annotation: "Renderer event handlers") do
        loop do
          message = @in.dequeue

          case message
          in :render
            rerender!
          in [:handle_callback, callback_id, payload]
            @vtree.handle_event(callback_id, payload)
          in [:handle_event, handler_id, payload]
            @vtree.handle_event(handler_id, payload)
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

    sig { returns(T.untyped) }
    def stylesheets = @vtree.stylesheets.dup

    private

    sig { params(args: T.untyped).void }
    def respond(*args) = @out.enqueue(args)

    sig {void}
    def rerender! = @vtree.render(@root)
  end
end
