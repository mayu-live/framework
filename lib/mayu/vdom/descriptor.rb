# typed: strict
# frozen_string_literal: true

require_relative "interfaces"
require_relative "../component"
require_relative "component_marshaler"
require_relative "children"
require_relative "./special_elements"

module Mayu
  module VDOM
    class Descriptor < T::Struct
      class FactoryImpl
        extend T::Sig
        include Interfaces::Descriptor::Factory

        sig { override.returns(Descriptor) }
        def comment
          Descriptor[Interfaces::Descriptor::COMMENT]
        end

        sig { override.params(text_content: T.untyped).returns(Descriptor) }
        def text(text_content)
          Descriptor[
            Interfaces::Descriptor::TEXT,
            text_content: text_content.to_s
          ]
        end

        sig { override.params(obj: T.untyped).returns(Descriptor) }
        def or_text(obj)
          Descriptor === obj ? obj : text(obj.to_s)
        end

        sig do
          override
            .params(children: Component::Children, parent_type: T.untyped)
            .returns(T::Array[Descriptor])
        end
        def clean(children, parent_type: nil)
          cleaned = Array(children).flatten.select(&:itself) # Remove anything falsy

          if parent_type == :title
            # <title> can only have text children
            cleaned.map { text(_1) }
          else
            cleaned.map { or_text(_1) }
          end
        end

        sig do
          override
            .params(descriptors: T::Array[Interfaces::Descriptor])
            .returns(T::Array[Interfaces::Descriptor])
        end
        def add_comments_between_texts(descriptors)
          comment = self.comment

          [*descriptors, nil].each_cons(2)
            .flat_map do |curr, succ|
              if curr&.text? && succ&.text?
                [curr, comment]
              else
                curr
              end
            end
            .compact
        end
      end

      Factory = T.let(FactoryImpl.new, FactoryImpl)

      extend T::Sig
      include Interfaces::Descriptor

      const :type, Component::ElementType
      const :props, Component::Props
      const :key, T.untyped
      const :slot, T.nilable(String)

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

      ##
      # This is used for hash comparisons,
      # https://ruby-doc.org/3.2.0/Hash.html#class-Hash-label-User-Defined+Hash+Keys
      sig { override.params(other: T.untyped).returns(T::Boolean) }
      def eql?(other) = self.class === other && same?(other)

      sig { override.returns(T::Boolean) }
      def component? = Component.component_class?(@type)

      sig { override.returns(T.class_of(Component::Base)) }
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

      sig { override.params(other: Interfaces::Descriptor).returns(T::Boolean) }
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
