# typed: strict

require "async/barrier"
require_relative "helpers"

module Mayu
  module Component
    class Wrapper
      extend T::Sig

      UpdateProc =
        T.type_alias do
          T.any(
            T.proc.params(arg0: State).returns(State),
            T.proc.params(kwargs: T.untyped).returns(State)
          )
        end

      sig { returns(String) }
      def vnode_id = @vnode.id

      sig { returns(Props) }
      attr_accessor :props
      sig { returns(State) }
      attr_accessor :state
      sig { returns(State) }
      attr_reader :next_state

      sig { returns(Helpers) }
      attr_reader :helpers

      sig { returns(T::Boolean) }
      def dirty? = @dirty
      sig { returns(TrueClass) }
      def dirty! = @dirty = true

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
        if derived_state =
             @instance.class.get_derived_state_from_props(props, state)
          @state = @state.merge(derived_state)
        end

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
        params(new_state: T.nilable(State), block: T.nilable(UpdateProc)).void
      end
      def update(new_state = nil, &block)
        if new_state
          @next_state = @next_state.merge(new_state)
          enqueue_update!
        end

        return unless block

        if block.parameters in [[:opt, var]]
          Console.logger.warn(self, <<~EOF) unless var == :state
            update do |#{var}|
            # Are you sure you didn't misspell `#{var}`?
            # Usually it should be called `state`.
            end
            EOF

          update(block.call(@next_state))
        else
          if block.parameters.all? { _1 in [:key | :keyreq, key] }
            keys = block.parameters.map(&:last)
            sliced_state = T.unsafe(@next_state).slice(*keys)
            update(block.call(**sliced_state))
          else
            raise ArgumentError, "All arguments to #update are not keys."
          end
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

      private

      sig { void }
      def enqueue_update!
        @vnode.enqueue_update!
        @dirty = true
      end
    end
  end
end
