# typed: strict

require_relative "../component"
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
        @removed = T.let(false, T::Boolean)
        # TODO:
        # VNodes should keep track of the associated stylesheet and whenever
        # the styhesheets differ, they should unload the old one and load the new...
        # @stylesheet = T.let(nil, T.nilable(Module::CSSModule::Base))
      end

      sig { returns(T::Boolean) }
      def removed? = @removed
      sig { void }
      def remove! = @removed = true
      sig { returns(T::Boolean) }
      def assert_not_removed!
        return true unless removed?
        raise "VNode is marked as removed and should not be used!"
      end

      sig { returns(T.untyped) }
      def marshal_dump
        assert_not_removed!
        [@id, @dom_parent_id, @component, @children, @descriptor]
      end

      sig { params(a: T.untyped).void }
      def marshal_load(a)
        @id, @dom_parent_id, @component, @children, @descriptor = a
        @removed = false

        if @component
          @component.instance_variable_set(:@vnode, self)
          instance = descriptor.component_class.new(@component)
          @component.instance_variable_set(:@instance, instance)
          instance.instance_variable_set(:@wrapper, @component)
          @component.instance_variable_set(
            :@helpers,
            Component::Helpers.new(self)
          )
        end
      end

      sig { params(block: T.proc.params(vnode: VNode).void).void }
      def traverse(&block)
        yield self

        children.each { |child| child.traverse(&block) }
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
        @vtree.session.fetch(url, method:, headers:, body:)
      end

      # sig { returns(Mayu::State::Store) }
      # def store = @vtree.session.store

      sig { returns(T.nilable(Component::Wrapper)) }
      def init_component
        @component ||= Component.wrap(self, type, props)
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
        T.must(StringIO.new.tap { write_html(_1) }.tap(&:rewind).read)
      end

      Writable =
        T.type_alias do
          T.any(Async::HTTP::Body::Writable, Brotli::Writer, StringIO)
        end

      sig { params(io: Writable, opts: T.untyped).void }
      def write_html(io, **opts)
        type = descriptor.type

        case type
        when Descriptor::TEXT
          text = descriptor.text
          if text.empty?
            # A zero-width-space will generate a text node in the DOM.
            io.write("&ZeroWidthSpace;")
          else
            io.write(CGI.escape_html(descriptor.text))
          end
          return
        when Descriptor::COMMENT
          io.write("<!--mayu-id=#{@id}-->")
          return
        when :__mayu_links
          io.write(opts[:links].to_s)
          return
        when :__mayu_scripts
          io.write(opts[:scripts].to_s)
          return
        end

        cleaned_children = children

        if descriptor.component?
          cleaned_children.each { _1.write_html(io, **opts) }
          return
        end

        io.write("<#{type}")

        io.write(%< data-mayu-id="#{@id.to_s}">)

        format_props { |formatted_prop| io.write(formatted_prop) }

        io.write(">")

        return if type.is_a?(Symbol) && Mayu::HTML.void_tag?(type)

        if dangerously_set_inner_html =
             props.dig(:dangerously_set_inner_html, :__html)
          io.write(dangerously_set_inner_html)
        else
          cleaned_children.each { _1.write_html(io, **opts) }
        end

        io.write("</#{type}>")
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
    end
  end
end
