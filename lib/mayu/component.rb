# typed: strict

require_relative "component/wrapper"
require_relative "component/base"

module Mayu
  module Component
    module IDescriptor
      extend T::Sig
      extend T::Helpers
      abstract!

      sig { abstract.returns(Component::ElementType) }
      def type
      end

      sig { abstract.returns(Component::Props) }
      def props
      end

      sig { abstract.returns(T.untyped) }
      def key
      end

      sig { abstract.returns(String) }
      def slot
      end

      sig { abstract.params(other: IDescriptor).returns(T::Boolean) }
      def same?(other)
      end

      sig { returns(IDescriptor) }
      def itself = self

      sig do
        type_parameters(:R)
          .params(
            block:
              T.proc.params(arg0: IDescriptor).returns(T.type_parameter(:R))
          )
          .returns(T.type_parameter(:R))
      end
      def then(&block) = yield self
    end

    extend T::Sig

    Props = T.type_alias { T::Hash[Symbol, T.untyped] }
    State = T.type_alias { T::Hash[Symbol, T.untyped] }

    LambdaComponent =
      T.type_alias do
        T.proc.params(kwargs: Props).returns(T.nilable(IDescriptor))
      end

    ComponentType = T.type_alias { T.any(T.class_of(Base), LambdaComponent) }

    Children = T.type_alias { T.any(ChildType, T::Array[ChildType]) }

    ChildType =
      T.type_alias do
        T.nilable(T.any(IDescriptor, T::Boolean, String, Numeric))
      end

    ElementType = T.type_alias { T.any(Symbol, ComponentType) }

    sig { params(other: T.untyped).returns(T::Boolean) }
    def self.===(other)
      component_class?(other)
    end

    sig { params(klass: T.untyped).returns(T::Boolean) }
    def self.component_class?(klass)
      !!(klass.is_a?(Class) && klass < Base)
    end

    sig do
      params(vnode: VDOM::VNode, type: T.untyped, props: Props).returns(
        T.nilable(Wrapper)
      )
    end
    def self.wrap(vnode, type, props)
      component_class?(type) ? Wrapper.new(vnode, type, props) : nil
    end
  end
end
