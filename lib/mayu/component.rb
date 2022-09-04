# typed: strict

require_relative "component/wrapper"
require_relative "component/base"
require_relative "component/special_components"

module Mayu
  module Component
    extend T::Sig

    Props = T.type_alias { T::Hash[Symbol, T.untyped] }
    State = T.type_alias { T::Hash[String, T.untyped] }

    LambdaComponent =
      T.type_alias do
        T.proc.params(kwargs: Props).returns(T.nilable(VDOM::Descriptor))
      end

    ComponentType = T.type_alias { T.any(T.class_of(Base), LambdaComponent) }

    Children = T.type_alias { T.any(ChildType, T::Array[ChildType]) }

    ChildType =
      T.type_alias do
        T.nilable(T.any(VDOM::Descriptor, T::Boolean, String, Numeric))
      end

    ElementType = T.type_alias { T.any(Symbol, ComponentType) }

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
