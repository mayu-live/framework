# typed: strict

require "bundler/setup"
require "sorbet-runtime"
require_relative "descriptor_builder"

module Mayu
  module Markup
    class Builder
      extend T::Sig

      sig { returns(T::Array[T::Array[VDOM::Descriptor]]) }
      attr_reader :streams

      sig { void }
      def initialize
        @streams = T.let([], T::Array[T::Array[VDOM::Descriptor]])
        @element_builder = T.let(DescriptorBuilder.new(self), DescriptorBuilder)
      end

      sig { params(node: VDOM::Descriptor).returns(T.self_type) }
      def <<(node)
        streams.last&.<< node
        self
      end

      sig do
        params(
          text_or_component:
          T.nilable(T.any(T.untyped, VDOM::Descriptor::ComponentType)),
          component_props: T.untyped,
          block: T.nilable(T.proc.void)
        ).returns(DescriptorBuilder)
      end
      def h(text_or_component = nil, **component_props, &block)
        case text_or_component
        when nil
          # do nothing
        when VDOM::Descriptor
          @streams.last&.push(text_or_component)
        when Class, Proc
          @streams.last&.push(VDOM::Descriptor.new(text_or_component, component_props, block ? capture(&block) : []))
        else
          @streams.last&.push(VDOM::Descriptor.text(text_or_component.to_s))
        end

        @element_builder
      end

      sig do
        params(block: T.proc.void).returns(
          T.nilable(T::Array[VDOM::Descriptor])
        )
      end
      def capture(&block)
        @streams.push([])
        yield
        # instance_eval(&block)
        @streams.pop
      end
    end
  end
end
