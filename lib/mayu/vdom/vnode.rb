# typed: strict
# frozen_string_literal: true

require_relative "../component"
require_relative "descriptor"
require_relative "dom"
require_relative "interfaces"
require_relative "id_generator"
require_relative "../html"

module Mayu
  module VDOM
    class VNode < T::Struct
      extend T::Sig

      Children = T.type_alias { T::Array[VNode] }
      Id = T.type_alias { IdGenerator::Type }

      sig do
        params(
          vtree: VTree,
          dom_parent_id: Id,
          descriptor: Interfaces::Descriptor,
          task: Async::Task
        ).returns(VNode)
      end
      def self.build(
        vtree,
        dom_parent_id,
        descriptor,
        task: Async::Task.current
      )
        new(id: vtree.next_id!, vtree:, dom_parent_id:, descriptor:, task:)
      end

      const :id, Id
      const :vtree, Interfaces::VTree
      const :dom_parent_id, Id
      prop :descriptor, Interfaces::Descriptor
      const :task, Async::Task, factory: -> { Async::Task.current }
      prop :children, Children, default: []
      prop :removed, T::Boolean, default: false
      prop :wrapper, T.nilable(Component::Wrapper)
      alias component wrapper

      sig { returns(Component::ElementType) }
      def type = descriptor.type
      sig { returns(Component::Props) }
      def props = descriptor.props
      sig { returns(T.untyped) }
      def key = descriptor.key

      sig { returns(Id) }
      def dom_id = (wrapper ? children.first&.dom_id || "root" : id)
      sig { returns(T::Boolean) }
      def dom? = type.is_a?(Symbol)

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
        [@id, @dom_parent_id, @wrapper, @children, @descriptor]
      end

      sig { params(a: T.untyped).void }
      def marshal_load(a)
        @id, @dom_parent_id, @wrapper, @children, @descriptor = a
        @removed = false

        if @wrapper
          @wrapper.instance_variable_set(:@vnode, self)
          instance = descriptor.component_class.new(@wrapper)
          @wrapper.instance_variable_set(:@instance, instance)
          instance.instance_variable_set(:@wrapper, @wrapper)
          @wrapper.instance_variable_set(
            :@helpers,
            Component::Helpers.new(@wrapper)
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
        @wrapper ||= Component.wrap(self, type, props)
      end

      sig { params(path: String).void }
      def navigate(path)
        @vtree.navigate(path)
      end

      sig { params(type: Symbol, payload: T.untyped).void }
      def action(type, payload)
        @vtree.action(type, payload)
      end

      sig { void }
      def enqueue_update!
        @vtree.enqueue_update!(self)
      end

      sig { params(descriptor: Interfaces::Descriptor).returns(T::Boolean) }
      def same?(descriptor)
        self.descriptor.eql?(descriptor)
      end

      sig { params(other: T.untyped).returns(T::Boolean) }
      def eql?(other)
        self.class === other && other.id == id
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
        when Mayu::VDOM::Interfaces::Descriptor::TEXT
          text = descriptor.text
          if text.empty?
            # A zero-width-space will generate a text node in the DOM.
            io.write("&ZeroWidthSpace;")
          else
            io.write(CGI.escape_html(descriptor.text))
          end
          return
        when Mayu::VDOM::Interfaces::Descriptor::COMMENT
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

        cleaned_children.each { _1.write_html(io, **opts) }

        io.write("</#{type}>")
      end

      sig { params(block: T.proc.params(arg0: String).void).void }
      def format_props(&block)
        props.each do |prop, value|
          next unless value
          next if prop == :children
          next if prop == :slot
          next if value == ""

          if value.is_a?(Hash)
            if prop == :style
              yield format_attr(prop, CSSAttributes.new(**value).to_s)
            else
              Utils
                .flatten_props(value, [prop.to_s])
                .each { yield format_prop(_1, _2) }
            end
            next
          end

          yield format_prop(prop, value)
        end
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

      sig { params(prop: Symbol, value: T.untyped).returns(T.untyped) }
      def format_prop(prop, value)
        value = prop.to_s if value == true

        prop = :value if prop == :initial_value

        attr = prop.to_s.sub(/^on_/, "on").tr("_", "-")

        format_attr(attr, value)
      end
    end
  end
end
