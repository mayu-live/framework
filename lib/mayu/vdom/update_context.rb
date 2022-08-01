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
        @dom_parents = T.let([], T::Array[VNode])
      end

      sig { returns(T.nilable(VNode)) }
      def parent = @parents.last

      sig { returns(T.nilable(VNode)) }
      def dom_parent = @dom_parents.last

      sig { params(vnode: VNode, blk: T.proc.void).void }
      def enter(vnode, &blk)
        dom_parent = vnode.descriptor.element?
        @parents.push(vnode)
        @dom_parents.push(vnode) if dom_parent
        yield
      ensure
        @dom_parents.pop if dom_parent
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
        # p caller.grep(/markup/).first(5)
        html = vnode.inspect_tree(exclude_components: true)
        ids = vnode.id_tree

        if before
          add_patch(
            :insert,
            id: vnode.id,
            parent: dom_parent&.id,
            before: before.id,
            html:,
            ids:
          )
        elsif after
          add_patch(
            :insert,
            id: vnode.id,
            parent: dom_parent&.id,
            after: after.id,
            html:,
            ids:
          )
        else
          add_patch(:insert, id: vnode.id, parent: dom_parent&.id, html:, ids:)
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
            id: vnode.id,
            parent: dom_parent&.id,
            before: before.id
          )
        elsif after
          add_patch(
            :move,
            id: vnode.id,
            parent: dom_parent&.id,
            after: after.id
          )
        else
          add_patch(:move, id: vnode.id, parent: dom_parent&.id)
        end
      end

      sig { params(vnode: VNode, attr: String, value: T.nilable(String)).void }
      def css(vnode, attr, value = nil)
        if value
          add_patch(:css, id: vnode.id, attr:, value:)
        else
          add_patch(:css, id: vnode.id, attr:)
        end
      end

      sig { params(vnode: VNode, text: String, append: T::Boolean).void }
      def text(vnode, text, append: false)
        if append
          add_patch(:text, id: vnode.id, append: text)
        else
          add_patch(:text, id: vnode.id, text:)
        end
      end

      sig { params(vnode: VNode).void }
      def remove(vnode)
        add_patch(:remove, id: vnode.id, parent: dom_parent&.id)
      end

      sig { params(vnode: VNode).void }
      def remove(vnode)
        add_patch(:remove, id: vnode.id, parent: dom_parent&.id)
      end

      sig { params(vnode: VNode, name: String, value: String).void }
      def set_attribute(vnode, name, value)
        add_patch(:attr, id: vnode.id, name:, value:)
      end

      sig { params(vnode: VNode, name: String).void }
      def remove_attribute(vnode, name)
        add_patch(:attr, id: vnode.id, name:)
      end

      private

      sig { params(type: Symbol, args: T.untyped).void }
      def add_patch(type, **args)
        puts "\e[33m#{type}:\e[0m #{args.inspect}"
        @patches.push(args.merge(type:))
      end
    end
  end
end
