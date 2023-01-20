# typed: strict

require "sorbet-runtime"

module Mayu
  module VDOM
    module H
      class << self
        extend T::Sig

        sig do
          params(
            type: Component::ElementType,
            children: T.any(Component::Children, Component::ChildType),
            props: T.untyped
          ).returns(Descriptor)
        end
        def [](type, *children, **props)
          T.unsafe(Descriptor)[type, *children, **props]
        end

        alias h []
      end
    end
  end
end
