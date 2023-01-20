# typed: strict
# frozen_string_literal: true

require_relative "../component"
require_relative "component_marshaler"
require_relative "children"
require_relative "./special_elements"

module Mayu
  module VDOM
    class Descriptor < T::Struct
      extend T::Sig
      include Component::IDescriptor

      const :type, Component::ElementType
      const :props, Component::Props
      const :key, T.untyped
      const :slot, T.nilable(String)

      TEXT = :TEXT
      COMMENT = :COMMENT

      sig { returns(Descriptor) }
      def self.comment = self[COMMENT]

      sig { params(text_content: T.untyped).returns(Descriptor) }
      def self.text(text_content) = self[TEXT, text_content: text_content.to_s]

      sig { params(descriptor: T.untyped).returns(Descriptor) }
      def self.or_text(descriptor)
        descriptor.is_a?(self) ? descriptor : text(descriptor)
      end

      sig do
        params(
          type: Component::ElementType,
          children: T.untyped,
          props: T.untyped
        ).returns(Descriptor)
      end
      def self.[](type, *children, **props)
        type = T.let(SpecialElements.for_type(type), Component::ElementType)

        children = Children.new(children, parent_type: type)
        props = props.merge(children:)
        key = props.delete(:key)
        slot = props.delete(:slot)&.to_s

        new(type:, key:, slot:, props:)
      end

      sig { returns(T::Array[T.untyped]) }
      def marshal_dump
        [ComponentMarshaler.new(type), Marshalling.dump_props(props), key, slot]
      end

      sig { params(a: T::Array[T.untyped]).void }
      def marshal_load(a)
        @type, @props, @key, @slot = a
        freeze
      end

      sig { returns(T::Boolean) }
      def text? = @type == TEXT
      sig { returns(T::Boolean) }
      def comment? = @type == COMMENT
      sig { returns(T::Boolean) }
      def element? = @type.is_a?(Symbol)
      sig { returns(T::Boolean) }
      def component? = Component.component_class?(@type)
      sig { returns(Children) }
      def children = props[:children]
      sig { returns(T::Boolean) }
      def has_children? = children.any?

      sig { returns(T.class_of(Component::Base)) }
      def component_class
        if Component.component_class?(@type)
          T.cast(@type, T.class_of(Component::Base))
        else
          raise "#{@type.inspect} is not a component class"
        end
      end

      sig { returns(String) }
      def to_s
        return text if text?
        return "" if comment?
        "#<Descriptor type=#{type.inspect}>"
      end

      sig { returns(String) }
      def text = @props[:text_content].to_s

      sig { override.params(other: Component::IDescriptor).returns(T::Boolean) }
      def same?(other)
        if key == other.key && type == other.type
          if type == :input
            # Inputs are considered to be different if their type changes.
            # Is this a good behavior? I think maybe it comes from from Preact.
            props[:type] == other.props[:type]
          else
            true
          end
        else
          false
        end
      end
    end
  end
end
