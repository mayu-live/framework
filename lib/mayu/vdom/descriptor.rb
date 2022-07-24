# typed: strict

require_relative "component"

module Mayu
  module VDOM
    class Descriptor
      extend T::Sig

      ElementType = T.type_alias { T.any(Symbol, T.class_of(Component::Base)) }
      Children = T.type_alias { T.any(ChildType, T::Array[ChildType]) }
      ChildType = T.type_alias { T.nilable(Descriptor) }
      ComponentChildren = T.type_alias { T.any(ComponentChildType, T::Array[ComponentChildType]) }
      ComponentChildType = T.type_alias { T.nilable(T.any(Descriptor, T::Boolean, String, Numeric)) }

      TEXT = :TEXT
      COMMENT = :COMMENT

      sig {returns(ElementType)}
      attr_reader :type
      sig {returns(Component::Props)}
      attr_reader :props
      sig {returns(T.untyped)}
      attr_reader :key

      sig {params(type: ElementType, props: Component::Props, children: Descriptor::ComponentChildren).void}
      def initialize(type, props = {}, children = [])
        @type = type
        @props = T.let(props.merge(
          children: Array(children).flatten.compact.map { |child|
            if child.is_a?(Descriptor)
              child
            else
              self.class.new(TEXT, { text_content: child })
            end
          }
        ), Component::Props)

        @key = T.let(@props.delete(:key), T.untyped)
      end

      sig {returns(T::Boolean)}
      def text? = @type == TEXT
      sig {returns(T::Boolean)}
      def comment? = @type == COMMENT
      sig {returns(T::Boolean)}
      def element? = @type.is_a?(Symbol)
      sig {returns(T::Boolean)}
      def component? = Component.component_class?(@type)

      sig {returns(String)}
      def text = @props[:text_content].to_s
    end
  end
end
