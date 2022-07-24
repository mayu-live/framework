# typed: strict

require_relative "component"
require_relative "descriptor"
require_relative "../renderer/dom"

module Mayu
  module VDOM
    class VNode
      extend T::Sig

      Children = T.type_alias { T::Array[T.nilable(VNode)] }

      sig {returns(Descriptor)}
      attr_accessor :descriptor
      sig {returns(Descriptor::ElementType)}
      def type = descriptor.type
      sig {returns(Component::Props)}
      def props = descriptor.props
      sig {returns(T.untyped)}
      def key = descriptor.key
      sig {returns(Children)}
      attr_accessor :children
      sig {returns(DOM::Node)}
      attr_accessor :dom

      sig {returns(T.nilable(Component::Wrapper))}
      attr_reader :component

      sig {returns(T.nilable(DOM::Node))}
      attr_reader :dom

      sig {params(vtree: VTree, descriptor: Descriptor, dom: T.nilable(DOM::Node)).void}
      def initialize(vtree, descriptor, dom = nil)
        @dom = dom
        @id = T.let(vtree.next_id!, Integer)
        @vtree = vtree
        @descriptor = descriptor
        @children = T.let([], Children)
        @component = T.let(nil, T.nilable(Component::Wrapper))
        init_component
      end

      sig {returns(T.nilable(Component::Wrapper))}
      def init_component
        return @component if @component

        type = descriptor.type

        if type.is_a?(Class) && type < Component
          @component = Component::Wrapper.new(self, type, props)
        else
          nil
        end
      end

      sig {void}
      def enqueue_update!
        @vtree.enqueue_update(self)
      end

      sig {params(descriptor: Descriptor).returns(T::Boolean)}
      def same?(descriptor)
        descriptor.type == type && descriptor.key == key
      end

      sig {params(level: Integer, exclude_components: T::Boolean).returns(String)}
      def inspect_tree(level = 0, exclude_components: false)
        indent = "  " * level
        type = descriptor.type

        if type == Descriptor::TEXT
          return indent + descriptor.text
        end

        if component && exclude_components
          return Array(children).flatten.compact.map {
            _1.inspect_tree(level, exclude_components:)
          }.join("\n")
        end

        formatted_props = props.reject { _1 == :children }.map { |key, value|
          format(
            ' %<key>s="%<value>s"',
            key: key.to_s.sub(/^on_/, "on").tr("_", "-"),
            value: CGI.escape(value.to_s),
          )
        }

        formatted_props.unshift(%< data-mayu-key="#{descriptor.key.to_s}">) if descriptor.key
        formatted_props.unshift(%< data-mayu-id="#{@id.to_s}">)

        cleaned_children = Array(children).flatten.compact

        if cleaned_children.empty?
          return indent + "<#{type.to_s}#{formatted_props.join} />"
        end

        [
          indent + "<#{type.to_s}#{formatted_props.join}>",
          *Array(children).flatten.compact.map {
            _1.inspect_tree(level.succ, exclude_components:)
          },
          indent + "</#{type.to_s}>"
        ].join("\n")
      end
    end
  end
end
