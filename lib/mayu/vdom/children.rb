# typed: strict
# frozen_string_literal: true

require_relative "../component"
require_relative "component_marshaler"

module Mayu
  module VDOM
    Slots = T.type_alias { T::Hash[T.nilable(String), T::Array[Descriptor]] }

    class Children
      extend T::Sig
      extend T::Generic
      include Enumerable

      Elem = type_member { { fixed: Descriptor } }

      sig { params(descriptors: T::Array[Descriptor]).void }
      def initialize(descriptors)
        @descriptors = descriptors
        @slots = T.let(nil, T.nilable(Slots))
      end

      sig { returns(T::Array[Descriptor]) }
      def to_a = @descriptors

      sig { params(other: T.untyped).returns(T::Boolean) }
      def ==(other)
        case other
        when Children
          @descriptors == other.to_a
        when Array
          @descriptors == other
        else
          false
        end
      end

      sig { returns(T::Boolean) }
      def empty? = @descriptors.empty?

      sig do
        params(
          name: T.nilable(String),
          fallback: T.nilable(T.proc.returns(Descriptor))
        ).returns(
          T.nilable(T.any(VDOM::Descriptor, T::Array[VDOM::Descriptor]))
        )
      end
      def slot(name = nil, &fallback)
        case slots.fetch(name, [])
        in []
          yield if block_given?
        in [one]
          one
        in [*many] unless name
          many
        in [*many]
          raise "Got #{many.size} slots one slot with name #{name.inspect}, #{many.map(&:type).inspect}"
        end
      end

      sig { returns(String) }
      def join = @descriptors.join

      sig { returns(Slots) }
      def slots = @slots ||= @descriptors.group_by(&:slot)

      sig do
        override
          .params(block: T.proc.params(arg0: T.untyped).returns(BasicObject))
          .returns(T.untyped)
      end
      def each(&block)
        @descriptors.each(&block)
      end
    end
  end
end
