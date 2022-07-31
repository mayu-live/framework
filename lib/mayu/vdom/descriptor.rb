# typed: strict

require_relative "component"

module Mayu
  module VDOM
    class Descriptor
      extend T::Sig

      ElementType = T.type_alias { T.any(Symbol, T.class_of(Component::Base)) }
      Children = T.type_alias { T.any(ChildType, T::Array[ChildType]) }
      ChildType = T.type_alias { T.nilable(Descriptor) }
      ComponentChildren =
        T.type_alias { T.any(ComponentChildType, T::Array[ComponentChildType]) }
      ComponentChildType =
        T.type_alias do
          T.nilable(T.any(Descriptor, T::Boolean, String, Numeric))
        end

      TEXT = :TEXT
      COMMENT = :COMMENT

      sig { params(children: ComponentChildren).returns(ComponentChildren) }
      def self.separate_texts_with_comments(children)
        Array(children).flatten.compact.map { |child| }
      end

      sig { returns(ElementType) }
      attr_reader :type
      sig { returns(Component::Props) }
      attr_reader :props
      sig { returns(T.untyped) }
      attr_reader :key

      sig do
        params(
          type: ElementType,
          props: Component::Props,
          children: ComponentChildren
        ).void
      end
      def initialize(type, props = {}, children = [])
        @type = T.let(convert_special_type(type), ElementType)

        children =
          Array(children)
            .flatten
            .compact
            .map do |child|
              case
              when child.is_a?(Descriptor)
                child
              when type == :title
                self.class.new(TEXT, { text_content: child.to_s })
              else
                [
                  # Comment nodes are to split text nodes in the DOM.
                  Descriptor.new(COMMENT),
                  self.class.new(TEXT, { text_content: child.to_s })
                ]
              end
            end
            .flatten

        # children = children.map.with_index { |child, i|
        #   if i > 0 && children[i - 1]&.text? && child.text?
        #   else
        #     child
        #   end
        # }.flatten

        @props = T.let(props.merge(children:), Component::Props)

        @key = T.let(@props.delete(:key), T.untyped)
      end

      sig { returns(T::Boolean) }
      def text? = @type == TEXT
      sig { returns(T::Boolean) }
      def comment? = @type == COMMENT
      sig { returns(T::Boolean) }
      def element? = @type.is_a?(Symbol)
      sig { returns(T::Boolean) }
      def component? = Component.component_class?(@type)

      sig { returns(String) }
      def text = @props[:text_content].to_s

      private

      sig { params(type: ElementType).returns(ElementType) }
      def convert_special_type(type)
        # This allows us to inject some special markup
        case type
        when :head
          Component::Hax::HeadComponent
        when :body
          Component::Hax::BodyComponent
        when :__mayu_head
          :head
        when :__mayu_body
          :body
        else
          type
        end
      end
    end
  end
end
