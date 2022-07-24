# typed: strict

require_relative "vdom"
require_relative "vdom/vtree"
require_relative "vdom/component"
require_relative "modules/system"

module Mayu
  class Renderer
    extend T::Sig

    sig {returns(String)}
    attr_reader :html

    sig {void}
    def initialize
      @in = T.let(Async::Queue.new, Async::Queue)
      @out = T.let(Async::Queue.new, Async::Queue)
      @task = T.let(nil, T.nilable(Async::Task))

      modules = Mayu::Modules::System.new(
        File.join(Dir.pwd, "example", "app")
      )

      app = T.let(
        modules.load_component('App').klass,
        T.class_of(Mayu::VDOM::Component::Base)
      )

      @root = T.let(VDOM.h(app), VDOM::Descriptor)
      @vtree = T.let(VDOM::VTree.new(@root), VDOM::VTree)
      @html = T.let("", String)

      rerender!
    end

    sig {returns(T::Boolean)}
    def running? = @task&.running?

    sig {void}
    def start
      return if @task

      @task = Async do
        loop do
          message = @in.dequeue

          case message
          in :render
            rerender!
          in :handle_event, payload
            raise "Handle event: #{payload}"
          else
            puts "Invalid message: #{message.inspect}"
          end
        end
      end
    end

    sig {void}
    def stop
      respond(:close)
      @task&.stop
      @task = nil
    end

    sig {params(args: T.untyped).void}
    def send(*args) = @in.enqueue(args)
    sig {returns(T.untyped)}
    def take = @out.dequeue

    sig {returns(T.untyped)}
    def id_tree = @vtree.id_tree

    private

    sig {params(args: T.untyped).void}
    def respond(*args) = @out.enqueue(args)

    sig {void}
    def rerender!
      @vtree.render(@root)
      html = @vtree.inspect_tree(exclude_components: true)
      respond(:html, html)
      @html = html
    end
  end
end
