# typed: strict

require_relative "component"

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
      ComponentChildren =
        T.type_alias { T.any(ComponentChildType, T::Array[ComponentChildType]) }
      ComponentChildType =
        T.type_alias do
          T.nilable(T.any(Descriptor, T::Boolean, String, Numeric))
        end

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
                self.class.text(child)
              when !child.to_s.empty?
                self.class.text(child)
              end
            end
            .compact

        # children = children.map.with_index { |child, i|
        #   if i > 0 && children[i - 1]&.text? && child.text?
        #   else
        #     child
        #   end
        # }.flatten

        @props = T.let(props.merge(children:), Component::Props)

        @key = T.let(@props.delete(:key), T.untyped)
      end

      sig { params(level: Integer).returns(String) }
      def _dump(level)
        type =
          if component?
            klass = T.cast(@type, T.class_of(Component::Base))

            component = klass.name || klass.const_get(:MAYU_MODULE).fetch(:path)
            { component: }
          else
            @type
          end

        MessagePack.pack([type, Marshal.dump(@props), @key])
      end

      sig { params(str: String).returns(T.attached_class) }
      def self._load(str)
        type, props, key = MessagePack.unpack(str)
        obj = allocate
        obj.instance_variable_set(:@type, type)
        obj.instance_variable_set(:@props, Marshal.load(props))
        obj.instance_variable_set(:@key, key)
        obj
      end

      sig { returns(T::Boolean) }
      def text? = @type == TEXT
      sig { returns(T::Boolean) }
      def comment? = @type == COMMENT
      sig { returns(T::Boolean) }
      def element? = @type.is_a?(Symbol)
      sig { returns(T::Boolean) }
      def component? = Component::Base.component_class?(@type)
      sig { returns(T::Array[Descriptor]) }
      def children = props[:children]
      sig { returns(T::Boolean) }
      def children? = children.any?

      sig { returns(String) }
      def text
        text = @props[:text_content].to_s
        text.empty? ? "&ZeroWidthSpace;" : text
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
          Component::SpecialComponents::HeadComponent
        when :body
          Component::SpecialComponents::BodyComponent
        when :a
          Component::SpecialComponents::AComponent
        when :__mayu_head
          :head
        when :__mayu_body
          :body
        when :__mayu_a
          :a
        else
          type
        end
      end
    end
  end
end
