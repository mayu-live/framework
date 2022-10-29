# typed: strict

require "async/barrier"
require_relative "helpers"

module Mayu
  module Component
    class Wrapper
      extend T::Sig

      sig { returns(Props) }
      attr_accessor :props
      sig { returns(State) }
      attr_accessor :state

      sig do
        params(vnode: VDOM::VNode, klass: T.class_of(Base), props: Props).void
      end
      def initialize(vnode, klass, props = {})
        @vnode = vnode
        @props = T.let(props, Props)
        @state = T.let(klass.get_initial_state(**props), State)
        @next_state = T.let(@state.dup, State)
        @dirty = T.let(true, T::Boolean)
        @instance = T.let(klass.new(self), Base)
        @barrier = T.let(Async::Barrier.new, Async::Barrier)
        @helpers = T.let(Helpers.new(vnode), Helpers)
      end

      sig { returns(T::Array[String]) }
      def assets
        @instance.class.assets
      end

      sig { returns(T.nilable(Resources::Resource)) }
      def resource
        if @instance.class.respond_to?(:__resource)
          @instance.class.send(:__resource)
        end
      end

      sig { returns(T.untyped) }
      def marshal_dump
        [
          VDOM::Marshalling.dump_props(@props),
          VDOM::Marshalling.dump_state(@state)
        ]
      end

      sig { params(a: T.untyped).void }
      def marshal_load(a)
        @props, @state = a
        @next_state = @state.clone
        @dirty = true
        @barrier = Async::Barrier.new
      end

      sig { returns(Helpers) }
      attr_reader :helpers
      sig { returns(State) }
      attr_reader :state
      sig { returns(State) }
      attr_reader :next_state
      sig { returns(Props) }
      attr_reader :props
      sig { returns(String) }
      def vnode_id = @vnode.id

      sig { returns(T::Boolean) }
      def dirty? = @dirty
      sig { returns(TrueClass) }
      def dirty! = @dirty = true

      sig { void }
      def mount
        async { @instance.mount }
      end

      sig { params(prev_props: Props, prev_state: State).void }
      def did_update(prev_props, prev_state)
        async { @instance.did_update(prev_props, prev_state) }
      end

      sig { void }
      def unmount
        @instance.unmount
      ensure
        @barrier.stop
      end

      sig { returns(ChildType) }
      def render
        @instance.render
      rescue NotImplementedError => e
        raise NotImplementedError, "#{@instance} should implement #render"
      ensure
        @dirty = false
      end

      sig { params(next_props: Props, next_state: State).returns(T::Boolean) }
      def should_update?(next_props, next_state)
        @dirty || @instance.should_update?(next_props, next_state)
      end

      sig { params(blk: T.proc.void).void }
      def async(&blk)
        @barrier.async(&blk)
      end

      sig do
        params(
          new_state: T.nilable(State),
          blk: T.nilable(T.proc.params(arg0: State).returns(State))
        ).void
      end
      def update(new_state = nil, &blk)
        new_state = blk.call(state) if blk

        if new_state
          @next_state = @next_state.merge(new_state)

          enqueue_update!
        end
      end

      private

      sig { void }
      def enqueue_update!
        @vnode.enqueue_update!
        @dirty = true
      end
    end
  end
end
