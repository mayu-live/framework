# typed: strict

require_relative "handler_ref"
require_relative "../markup"

module Mayu
  module Component
    class Base
      extend T::Sig
      extend T::Helpers
      abstract!

      sig { overridable.params(props: T.untyped).returns(Component::State) }
      def self.get_initial_state(**props)
        {}
      end

      class << self
        extend T::Sig

        sig { void }
        def initialize
          # This will never be called but will make Sorbet happy
          @__mayu_module = T.let(nil, T.nilable(Resources::Resource))
        end

        sig { params(__mayu_module: Resources::Resource).void }
        attr_writer :__mayu_module

        sig { returns(Resources::Resource) }
        def __mayu_module
          @__mayu_module or raise "__mayu_module is not set"
        end

        sig { params(path: String).returns(T.class_of(Base)) }
        def self.import(path)
          __mayu_module.load_relative(path) => mod
          mod.type => Resources::Types::Ruby => ruby
          ruby.klass
        end
      end

      sig do
        overridable
          .params(props: Component::Props, state: Component::State)
          .returns(Component::State)
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
          .params(next_props: Component::Props, next_state: Component::State)
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

      sig { returns(Resources::Types::CSS::ClassnameProxy) }
      def styles
        raise "todo"
      end

      sig { params(blk: T.proc.bind(T.self_type).void).void }
      def async(&blk) = @__wrapper.async(&blk)

      sig { abstract.returns(ChildType) }
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

      sig { returns(Markup::Builder) }
      def h = Markup::Builder.new

      sig do
        params(
          state: T.nilable(State),
          blk: T.nilable(T.proc.params(arg0: State).returns(State))
        ).void
      end
      def update_state(state = nil, &blk)
        @__wrapper.update(state, &blk)
      end

      sig { returns(VDOM::Descriptor::Children) }
      def children = props[:children].compact
      sig { returns(VDOM::Descriptor::Children) }
      def children = props[:children]
    end
  end
end
