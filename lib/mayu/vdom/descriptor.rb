# typed: strict
# frozen_string_literal: true

require_relative "../component"
require_relative "component_marshaler"

module Mayu
  module VDOM
    class Descriptor
      extend T::Sig

      LambdaComponent =
        T.type_alias do
          T.proc.params(kwargs: Component::Props).returns(T.nilable(Descriptor))
        end

      ComponentType =
        T.type_alias { T.any(T.class_of(Component::Base), LambdaComponent) }

      ElementType = T.type_alias { T.any(Symbol, ComponentType) }

      Children = T.type_alias { T.any(ChildType, T::Array[ChildType]) }
      ChildType = T.type_alias { T.nilable(Descriptor) }

      TEXT = :TEXT
      COMMENT = :COMMENT

      sig { returns(Descriptor) }
      def self.comment = new(:COMMENT)

      sig { params(text_content: T.untyped).returns(Descriptor) }
      def self.text(text_content) =
        new(TEXT, { text_content: text_content.to_s })

      sig { params(descriptor: T.untyped).returns(Descriptor) }
      def self.or_text(descriptor)
        descriptor.is_a?(self) ? descriptor : text(descriptor)
      end

      sig { returns(ElementType) }
      attr_reader :type
      sig { returns(Component::Props) }
      attr_reader :props
      sig { returns(T.untyped) }
      attr_reader :key
      sig { returns(T.nilable(String)) }
      attr_reader :slot

      sig do
        params(children: Component::Children, parent_type: T.untyped).returns(
          T::Array[Descriptor]
        )
      end
      def self.clean_children(children, parent_type: nil)
        cleaned = Array(children).flatten.select(&:itself) # Remove anything falsy

        if parent_type == :title
          # <title> can only have text children
          cleaned.map { text(_1) }
        else
          cleaned.map { or_text(_1) }
        end
      end

      sig do
        params(descriptors: T::Array[Descriptor], parent_type: T.untyped).void
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

      sig do
        params(descriptors: T::Array[Descriptor]).returns(T::Array[Descriptor])
      end
      def self.add_comments_between_texts(descriptors)
        comment = Descriptor.comment
        prev = T.let(nil, T.nilable(Descriptor))

        descriptors
          .map
          .with_index do |curr, i|
            prev2 = prev
            prev = curr if curr

            prev2&.text? && curr.text? ? [comment, curr] : [curr]
          end
          .flatten
      end

      sig do
        params(
          type: ElementType,
          props: Component::Props,
          children: T.untyped
        ).void
      end
      def initialize(type, props = {}, children = [])
        @type = T.let(convert_special_type(type), ElementType)

        children = self.class.clean_children(children, parent_type: type)
        @props = T.let(props.merge(children:), Component::Props)
        @key = T.let(@props.delete(:key), T.untyped)
        @slot = T.let(@props.delete(:slot)&.to_s, T.nilable(String))
        freeze
      end

      sig { returns(T::Array[T.untyped]) }
      def marshal_dump
        [ComponentMarshaler.new(type), Marshalling.dump_props(props), key]
      end

      sig { params(a: T::Array[T.untyped]).void }
      def marshal_load(a)
        @type, @props, @key = a
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
      sig { returns(T::Array[Descriptor]) }
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
      def text
        @props[:text_content].to_s
      end

      sig { params(other: Descriptor).returns(T::Boolean) }
      def same?(other)
        if key == other.key && type == other.type
          type == :input ? props[:type] == props[:type] : true
        else
          false
        end
      end

      private

      sig { params(type: ElementType).returns(ElementType) }
      def convert_special_type(type)
        # This allows us to inject some special markup
        case type
        when :head
          Component::SpecialComponents::Head
        when :__mayu_head
          :head
        when :body
          Component::SpecialComponents::Body
        when :__mayu_body
          :body
        when :a
          Component::SpecialComponents::A
        when :__mayu_a
          :a
        when :select
          Component::SpecialComponents::Select
        when :__mayu_select
          :select
        else
          type
        end
      end
    end
  end
end
