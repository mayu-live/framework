# typed: strict
module Mayu
  module Component
    class Base
      extend T::Sig
      extend T::Helpers
      abstract!

      sig do
        overridable.params(props: T.untyped).returns(VDOM::Component::State)
      end
      def self.get_initial_state(**props)
        {}
      end

      sig do
        overridable
          .params(props: VDOM::Component::Props, state: VDOM::Component::State)
          .returns(VDOM::Component::State)
      end
      def self.get_derived_state_from_props(props, state)
        {}
      end

      sig { params(wrapper: Wrapper).void }
      def initialize(wrapper)
        @__wrapper = wrapper
      end

      sig { returns(State) }
      def state = @__wrapper.state
      sig { returns(Props) }
      def props = @__wrapper.props
      sig { returns(String) }
      def vnode_id = @__wrapper.vnode_id

      sig { overridable.void }
      def mount
      end

      sig { overridable.void }
      def unmount
      end

      sig do
        overridable
          .params(
            next_props: VDOM::Component::Props,
            next_state: VDOM::Component::State
          )
          .returns(T::Boolean)
      end
      def should_update?(next_props, next_state)
        case
        when props != next_props
          true
        when state != next_state
          true
        else
          false
        end
      end

      sig { returns(Modules2::ModuleTypes::CSS::ClassnameProxy) }
      def styles
        raise "todo"
      end

      sig { params(blk: T.proc.bind(T.self_type).void).void }
      def async(&blk) = @__wrapper.async(&blk)

      sig do
        abstract.returns(T.nilable(T.any(VDOM::Descriptor, [VDOM::Descriptor])))
      end
      def render
      end

      sig do
        params(name: Symbol, args: T.untyped, kwargs: T.untyped).returns(
          HandlerRef
        )
      end
      def handler(name, *args, **kwargs)
        HandlerRef.new(self, name, args, kwargs)
      end

      sig { returns(Helpers) }
      def helpers
        @__wrapper.helpers
      end

      sig do
        params(
          state: T.nilable(State),
          blk: T.nilable(T.proc.params(arg0: State).returns(State))
        ).void
      end
      def update_state(state = nil, &blk)
        @__wrapper.update(state, &blk)
      end
    end
  end
end
