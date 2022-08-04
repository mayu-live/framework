# typed: strict

require_relative "component"
require_relative "descriptor"
require_relative "dom"

module Mayu
  module VDOM
    class VNode
      extend T::Sig

      Children = T.type_alias { T::Array[VNode] }
      Id = T.type_alias { Integer }

      sig { returns(Id) }
      attr_reader :id

      sig { returns(Id) }
      attr_accessor :dom_parent_id

      sig { returns(Id) }
      def dom_id
        if component
          children.first&.dom_id || -1
        else
          id
        end
      end

      sig { returns(Descriptor) }
      attr_accessor :descriptor
      sig { returns(Descriptor::ElementType) }
      def type = descriptor.type
      sig { returns(Component::Props) }
      def props = descriptor.props
      sig { returns(T.untyped) }
      def key = descriptor.key
      sig { returns(Children) }
      attr_accessor :children

      sig { returns(T.nilable(Component::Wrapper)) }
      attr_reader :component

      sig { returns(T::Boolean) }
      def dom? = type.is_a?(Symbol)

      sig do
        params(vtree: VTree, dom_parent_id: Id, descriptor: Descriptor, task: Async::Task).void
      end
      def initialize(vtree, dom_parent_id, descriptor, task: Async::Task.current)
        @id = T.let(vtree.next_id!, Id)
        @dom_parent_id = dom_parent_id
        @vtree = vtree
        @descriptor = descriptor
        @children = T.let([], Children)
        @component = T.let(nil, T.nilable(Component::Wrapper))
      end

      sig { params(task: Async::Task).returns(T.nilable(Component::Wrapper)) }
      def init_component(task: Async::Task.current)
        @component ||= Component.wrap(self, type, props, task:)
      end

      sig { void }
      def enqueue_update!
        @vtree.enqueue_update!(self)
      end

      sig { params(descriptor: Descriptor).returns(T::Boolean) }
      def same?(descriptor)
        descriptor.type == type && descriptor.key == key
      end

      VOID_ELEMENTS =
        T.let(
          %w[
            area
            base
            br
            col
            command
            embed
            hr
            img
            input
            keygen
            link
            meta
            param
            source
            track
            wbr
          ].freeze,
          T::Array[String]
        )

      sig { returns(T.untyped) }
      def id_tree
        children = Array(self.children).flatten.compact

        return children.first&.id_tree if component

        children.empty? ? { id:, type: type.to_s } : { id:, ch: children.map(&:id_tree), type: type.to_s }
      end

      sig {returns(String)}
      def inspect
        "<#VNode:#{id} type=#{descriptor.type} key=#{descriptor.key}>"
      end

      sig do
        params(level: Integer, exclude_components: T::Boolean).returns(String)
      end
      def inspect_tree(level = 0, exclude_components: false)
        type = descriptor.type

        case type
        when Descriptor::TEXT
          return descriptor.text
          # return "(#{@id}):#{descriptor.text}"
        when Descriptor::COMMENT
          return "<!--mayu-id=#{@id}-->"
        end

        cleaned_children = children

        if component && exclude_components
          return(
            cleaned_children
              .map { _1.inspect_tree(level, exclude_components:) }
              .join("\n")
          )
        end

        formatted_props =
          props
            .reject { _1 == :children || _1 == :dangerously_set_inner_html }
            .map do |key, value|
              if key == :style && value.is_a?(Hash)
                next(
                  format(
                    ' %<key>s="%<value>s"',
                    key:,
                    value: CSSAttributes.new(**value).to_s
                  )
                )
              end

              format(
                ' %<key>s="%<value>s"',
                key:
                  key
                    .to_s
                    .sub(/^on_/, "on")
                    .sub(/\Ainitial_value\Z/, "value")
                    .tr("_", "-"),
                value: CGI.escape_html(value.to_s)
              )
            end

        if descriptor.key
          formatted_props.unshift(%< data-mayu-key="#{descriptor.key.to_s}">)
        end
        formatted_props.unshift(%< data-mayu-id="#{@id.to_s}">)

        if VOID_ELEMENTS.include?(type.to_s)
          return "<#{type}#{formatted_props.join}>"
        end

        if props[:dangerously_set_inner_html].is_a?(Hash)
          dangerously_set_inner_html =
            props[:dangerously_set_inner_html].fetch(:__html)
          return(
            "<#{type}#{formatted_props.join}>#{dangerously_set_inner_html}</#{type}>"
          )
        end

        [
          "<#{type}#{formatted_props.join}>",
          *cleaned_children.map do
            _1.inspect_tree(level.succ, exclude_components:)
          end,
          "</#{type}>"
        ].join
      end
    end
  end
end
