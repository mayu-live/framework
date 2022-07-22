# typed: strict

require_relative "renderer/vdom"

module Mayu
  module Renderer
    extend T::Sig

    sig {params(type: VDOM::ElementType, props: VDOM::Props, children: VDOM::Descriptor::Children).returns(VDOM::Descriptor)}
    def self.h(type, props = {}, children = [])
      VDOM::Descriptor.new(type, props, children)
    end
  end
end
