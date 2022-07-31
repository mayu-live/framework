# typed: strict

module Mayu
  module VDOM
    module H
      extend T::Sig

      sig do
        params(
          type: Descriptor::ElementType,
          props: Component::Props,
          children: T.nilable(Descriptor::ComponentChildren),
          blk: T.nilable(T.proc.returns(Descriptor::ComponentChildren))
        ).returns(Descriptor)
      end
      def h(type, props = {}, children = [], &blk)
        if blk
          Descriptor.new(type, props, blk.call)
        else
          Descriptor.new(type, props, children)
        end
      end
    end
  end
end
