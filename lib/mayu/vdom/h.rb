# typed: strict

require "sorbet-runtime"

module Mayu
  module VDOM
    module H
      extend T::Sig
      extend self

      sig do
        params(
          type: Descriptor::ElementType,
          children: T.any(Component::Children, Component::ChildType),
          props: T.untyped
        ).returns(Descriptor)
      end
      def h(type, *children, **props)
        Descriptor.new(type, props, children)
      end

      alias h2 h
    end
  end
end
