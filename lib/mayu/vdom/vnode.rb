# typed: strict

require_relative "component"
require_relative "descriptor"
require_relative "dom"

module Mayu
  module VDOM
    class VNode
      extend T::Sig

      Children = T.type_alias { T::Array[T.nilable(VNode)] }

      sig { returns(Integer) }
      attr_reader :id

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
      sig { returns(DOM::Node) }
      attr_accessor :dom
      sig { returns(Integer) }
      attr_accessor :parent_id

      sig { returns(T.nilable(Component::Wrapper)) }
      attr_reader :component

      sig { returns(T::Boolean) }
      def dom? = type.is_a?(Symbol)

      sig { returns(T.nilable(DOM::Node)) }
      attr_reader :dom

      sig do
        params(
          vtree: VTree,
          parent_id: Integer,
          descriptor: Descriptor,
          dom: T.nilable(DOM::Node)
        ).void
      end
      def initialize(vtree, parent_id, descriptor, dom = nil)
        @dom = dom
        @id = T.let(vtree.next_id!, Integer)
        @parent_id = parent_id
        @vtree = vtree
        @descriptor = descriptor
        @children = T.let([], Children)
        @component = T.let(nil, T.nilable(Component::Wrapper))
        init_component
      end

      sig { returns(T.nilable(Component::Wrapper)) }
      def init_component
        @component ||= Component.wrap(self, type, props)
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

        if children.empty?
          { i: @id }
        else
          { i: @id, c: children.map(&:id_tree).compact }
        end
      end

      sig do
        params(result: T::Hash[String, String]).returns(T::Hash[String, String])
      end
      def stylesheets(result = {})
        type = descriptor.type

        if Component.component_class?(type)
          css = T.cast(component.class, T.class_of(Component::Base)).stylesheets
          result[css.path] ||= css.to_s
        end

        children.each do |child|
          result.merge!(child.stylesheets(result)) if child
        end

        result
      end

      sig do
        params(level: Integer, exclude_components: T::Boolean).returns(String)
      end
      def inspect_tree(level = 0, exclude_components: false)
        type = descriptor.type

        case type
        when Descriptor::TEXT
          return descriptor.text
        when Descriptor::COMMENT
          return "<!--mayu-id=#{@id}-->"
        end

        cleaned_children = Array(children).flatten.compact

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
