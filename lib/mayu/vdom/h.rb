# typed: strict

require "sorbet-runtime"

module Mayu
  module VDOM
    module H
      extend T::Sig

      sig do
        params(
          type: Component::ElementType,
          children: T.any(Component::Children, Component::ChildType),
          props: T.untyped
        ).returns(Descriptor)
      end
      def self.[](type, *children, **props)
        T.unsafe(Descriptor)[type, *children, **props]
      end
    end
  end
end
