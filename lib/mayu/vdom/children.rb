# typed: strict
# frozen_string_literal: true

require_relative "children"
require_relative "../component"
require_relative "component_marshaler"

module Mayu
  module VDOM
    Slots =
      T.type_alias do
        T::Hash[T.nilable(String), T::Array[Interfaces::Descriptor]]
      end

    class Children
      extend T::Sig
      extend T::Generic
      include Enumerable

      include Interfaces::Children

      sig do
        params(
          descriptors: T::Array[Interfaces::Descriptor],
          parent_type: T.untyped
        ).void
      end
      def self.check_duplicate_keys(descriptors, parent_type: "??unknown??")
        keys = descriptors.map(&:key).compact
        duplicates = keys.reject { keys.rindex(_1) == keys.index(_1) }.uniq
        duplicates.each do |key|
          Console.logger.warn(
            self,
            "Duplicate keys detected: #{key.inspect}",
            "This may cause an update error!",
            "Parent type: #{parent_type.inspect}"
          )
        end
      end

      Elem = type_member { { fixed: Interfaces::Descriptor } }

      sig do
        params(
          descriptors: T::Array[Interfaces::Descriptor],
          parent_type: T.untyped
        ).void
      end
      def initialize(descriptors, parent_type: nil)
        @descriptors =
          T.let(
            Descriptor::Factory.clean(descriptors, parent_type:),
            T::Array[Interfaces::Descriptor]
          )
        @slots = T.let(nil, T.nilable(Slots))
      end

      sig { returns(T::Array[Interfaces::Descriptor]) }
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
        override
          .params(
            name: T.nilable(String),
            fallback: T.nilable(T.proc.returns(Interfaces::Descriptor))
          )
          .returns(
            T.nilable(
              T.any(Interfaces::Descriptor, T::Array[Interfaces::Descriptor])
            )
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
