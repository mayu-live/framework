# typed: strict

require "sorbet-runtime"
require_relative "../markup"

module Mayu
  module VDOM
    module H
      extend T::Sig

      sig do
        params(
          type: Descriptor::ElementType,
          children: Component::Children,
          props: T.untyped
        ).returns(Descriptor)
      end
      def h2(type, *children, **props)
        Descriptor.new(type, props, children)
      end

      sig { returns(Markup::Builder) }
      def h
        Markup::Builder.new
      end
    end
  end
end
