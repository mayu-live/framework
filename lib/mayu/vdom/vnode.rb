# typed: strict

require_relative "component"
require_relative "descriptor"
require_relative "dom"
require_relative "id_generator"
require_relative "../html"

module Mayu
  module VDOM
    class VNode
      extend T::Sig

      Children = T.type_alias { T::Array[VNode] }
      Id = T.type_alias { IdGenerator::Type }

      sig { returns(Id) }
      attr_reader :id

      sig { returns(Id) }
      attr_accessor :dom_parent_id

      sig { returns(Id) }
      def dom_id
        component ? children.first&.dom_id || "root" : id
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
        params(
          vtree: VTree,
          dom_parent_id: Id,
          descriptor: Descriptor,
          task: Async::Task
        ).void
      end
      def initialize(
        vtree,
        dom_parent_id,
        descriptor,
        task: Async::Task.current
      )
        @id = T.let(vtree.next_id!, Id)
        @dom_parent_id = dom_parent_id
        @vtree = vtree
        @descriptor = descriptor
        @children = T.let([], Children)
        @component = T.let(nil, T.nilable(Component::Wrapper))
        # TODO:
        # VNodes should keep track of the associated stylesheet and whenever
        # the styhesheets differ, they should unload the old one and load the new...
        # @stylesheet = T.let(nil, T.nilable(Module::CSSModule::Base))
      end

      sig do
        params(
          url: String,
          method: Symbol,
          headers: T::Hash[String, String],
          body: T.nilable(String)
        ).returns(Fetch::Response)
      end
      def fetch(url, method: :GET, headers: {}, body: nil)
        @vtree.session.fetch.fetch(url, method:, headers:, body:)
      end

      sig { returns(Mayu::State::Store) }
      def store = @vtree.session.store

      sig { params(task: Async::Task).returns(T.nilable(Component::Wrapper)) }
      def init_component(task: Async::Task.current)
        @component ||= Component.wrap(self, type, props, task:)
      end

      sig { params(path: String).void }
      def navigate(path)
        @vtree.navigate(path)
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
          { id:, type: type.to_s }
        else
          { id:, ch: children.map(&:id_tree), type: type.to_s }
        end
      end

      sig { returns(String) }
      def inspect
        "<#VNode:#{id} type=#{descriptor.type} key=#{descriptor.key}>"
      end

      sig { returns(String) }
      def to_html
        StringIO.new.tap { write_html(_1) }.tap(&:rewind).read
      end

      sig { params(io: StringIO).void }
      def write_html(io)
        type = descriptor.type

        case type
        when Descriptor::TEXT
          io << descriptor.text
          return
        when Descriptor::COMMENT
          io << "<!--mayu-id=#{@id}-->"
          return
        end

        cleaned_children = children

        if descriptor.component?
          cleaned_children.each { _1.write_html(io) }
          return
        end

        io << "<#{type}"

        io << %< data-mayu-id="#{@id.to_s}">

        io << %< data-mayu-key="#{descriptor.key.to_s}"> if descriptor.key

        format_props { |formatted_prop| io << formatted_prop }

        io << ">"

        return if Mayu::HTML.void_tag?(type)

        if dangerously_set_inner_html =
             props.dig(:dangerously_set_inner_html, :__html)
          io << dangerously_set_inner_html
        else
          cleaned_children.each { _1.write_html(io) }
        end

        io << "</#{type}>"
      end

      sig do
        params(attr: T.any(String, Symbol), value: T.untyped).returns(String)
      end
      def format_attr(attr, value)
        format(
          %{ %<attr>s="%<value>s"},
          attr: attr.to_s,
          value: CGI.escape_html(value.to_s)
        )
      end

      sig { params(block: T.proc.params(arg0: String).void).void }
      def format_props(&block)
        props
          .reject do |prop, value|
            next true unless value
            next true if prop == :children
            next true if prop == :dangerously_set_inner_html
            false
          end
          .each do |prop, value|
            if prop == :style && value.is_a?(Hash)
              yield format_attr(prop, CSSAttributes.new(**value).to_s)
              next
            end

            if HTML.boolean_attribute?(prop) || value.is_a?(TrueClass) ||
                 value.is_a?(FalseClass)
              value = prop.to_s
            end

            attr =
              prop
                .to_s
                .sub(/^on_/, "on")
                .sub(/\Ainitial_value\Z/, "value")
                .tr("_", "-")

            yield format_attr(attr, value)
          end
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
            .reject do
              _1 == :children || _1 == :dangerously_set_inner_html || !_2
            end
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

              if HTML.boolean_attribute?(key) || value.is_a?(TrueClass) ||
                   value.is_a?(FalseClass)
                value = key.to_s
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
