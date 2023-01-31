# typed: strict

module Mayu
  module VDOM
    class UpdateContext
      extend T::Sig

      sig { returns(T::Array[T.untyped]) }
      attr_reader :patches

      sig { void }
      def initialize
        @patches = T.let([], T::Array[T.untyped])
        @parents = T.let([], T::Array[VNode])
        @dom_parent_ids = T.let([], T::Array[VNode::Id])
        @stylesheets = T.let(Set.new, T::Set[String])
      end

      sig { returns(T.untyped) }
      def stylesheet_patch
        return [] if @stylesheets.empty?

        paths = @stylesheets.to_a.map { "/__mayu/static/#{_1}" }

        [{ type: :stylesheet, paths: }]
      end

      sig { returns(T.nilable(VNode)) }
      def parent = @parents.last

      sig { returns(VNode::Id) }
      def dom_parent_id = @dom_parent_ids.last || "probably root"

      sig { params(vnode: VNode, blk: T.proc.void).void }
      def enter(vnode, &blk)
        # Sleep so that the fiber yields,
        # so that other things can run..
        sleep(0)

        dom_parent_id =
          (vnode.descriptor.element? ? vnode.id : vnode.dom_parent_id)

        @parents.push(vnode)
        @dom_parent_ids.push(dom_parent_id) if dom_parent_id
        yield
      ensure
        @dom_parent_ids.pop if dom_parent_id
        @parents.pop
      end

      sig do
        params(
          vnode: VNode,
          before: T.nilable(VNode),
          after: T.nilable(VNode)
        ).void
      end
      def insert(vnode, before: nil, after: nil)
        html = vnode.to_html
        ids = vnode.id_tree

        if before
          add_patch(
            :insert,
            id: vnode.dom_id,
            parent: dom_parent_id,
            before: before.dom_id,
            html:,
            ids:
          )
        elsif after
          add_patch(
            :insert,
            id: vnode.dom_id,
            parent: dom_parent_id,
            after: after.dom_id,
            html:,
            ids:
          )
        else
          add_patch(
            :insert,
            id: vnode.dom_id,
            parent: dom_parent_id,
            html:,
            ids:
          )
        end
      end

      sig do
        params(
          vnode: VNode,
          before: T.nilable(VNode),
          after: T.nilable(VNode)
        ).void
      end
      def move(vnode, before: nil, after: nil)
        if before
          add_patch(
            :move,
            id: vnode.dom_id,
            parent: vnode.dom_parent_id,
            before: before.dom_id
          )
        elsif after
          add_patch(
            :move,
            id: vnode.dom_id,
            parent: vnode.dom_parent_id,
            after: after.dom_id
          )
        else
          add_patch(:move, id: vnode.dom_id, parent: vnode.dom_parent_id)
        end
      end

      sig { params(vnode: VNode, attr: String, value: T.nilable(String)).void }
      def css(vnode, attr, value = nil)
        if value
          add_patch(:css, id: vnode.dom_id, attr:, value:)
        else
          add_patch(:css, id: vnode.dom_id, attr:)
        end
      end

      sig { params(hash: String).void }
      def stylesheet(hash)
        @stylesheets.add(hash)
      end

      sig { params(vnode: VNode, text: String, append: T::Boolean).void }
      def text(vnode, text, append: false)
        if append
          add_patch(:text, id: vnode.dom_id, append: text)
        else
          add_patch(:text, id: vnode.dom_id, text:)
        end
      end

      sig { params(vnode: VNode).void }
      def remove(vnode)
        if vnode.component
          if child = vnode.children.first
            return remove(child)
          end
        end
        # puts "\e[31mremove\e[0m #{vnode.key}"
        add_patch(:remove, id: vnode.dom_id, parent: vnode.dom_parent_id)
      end

      sig { params(vnode: VNode, name: String, value: String).void }
      def set_attribute(vnode, name, value)
        add_patch(:attr, id: vnode.dom_id, name: attr_name(name), value:)
      end

      sig { params(vnode: VNode, name: String).void }
      def remove_attribute(vnode, name)
        add_patch(:attr, id: vnode.dom_id, name: attr_name(name))
      end

      private

      sig { params(type: Symbol, args: T.untyped).void }
      def add_patch(type, **args)
        # puts "\e[35;5mXXXXXX \e[33m#{type}:\e[0m #{args.inspect}"
        @patches.push(args.merge(type:))
      end

      sig { params(attr: T.any(String, Symbol)).returns(String) }
      def attr_name(attr)
        attr
          .to_s
          .sub(/^on_/, "on")
          .sub(/\Ainitial_value\Z/, "value")
          .tr("_", "-")
      end
    end
  end
end
