# typed: strict

require_relative "component"
require_relative "descriptor"
require_relative "dom"
require_relative "vnode"

module Mayu
  module VDOM
    class PatchSet
      extend T::Sig

      Patch = T.type_alias { { type: Symbol, payload: T.untyped } }

      sig { void }
      def initialize
        @patches = T.let([], T::Array[T::Hash[Symbol, String]])
      end

      sig { returns(T::Boolean) }
      def empty? = @patches.empty?

      sig { params(id: VNode::Id, text: String).void }
      def update_text(id, text)
        add_patch(:update_text, { id:, text: })
      end

      sig { params(id: VNode::Id, name: String, value: String).void }
      def set_attribute(id, name, value)
        add_patch(:set_attribute, { id:, name:, value: })
      end

      sig { params(id: VNode::Id, name: String).void }
      def remove_attribute(id, name)
        add_patch(:remove_attribute, { id:, name: })
      end

      sig do
        params(
          parent_id: VNode::Id,
          new_node: VNode,
          before_id: T.nilable(VNode::Id)
        ).void
      end
      def insert_before(parent_id, new_node, before_id = nil)
        add_patch(
          :insert,
          {
            id: new_node.id,
            parent_id:,
            before_id:,
            html: new_node.inspect_tree,
            ids: new_node.id_tree
          }
        )
      end

      sig do
        params(
          parent_id: VNode::Id,
          id: VNode::Id,
          before_id: T.nilable(VNode::Id)
        ).void
      end
      def move_before(parent_id, id, before_id)
        add_patch(:move, { parent_id:, id:, before_id: })
      end

      sig do
        params(
          parent_id: VNode::Id,
          id: VNode::Id,
          after_id: T.nilable(VNode::Id)
        ).void
      end
      def move_after(parent_id, id, after_id)
        add_patch(:move, { parent_id:, id:, after_id: })
      end

      sig { params(id: VNode::Id).void }
      def remove_node(id)
        add_patch(:remove, { id: })
      end

      sig { params(parent_id: VNode::Id, child_id: VNode::Id).void }
      def remove_child(parent_id, child_id)
        add_patch(:remove_child, { parent_id:, child_id: })
      end

      sig { params(node: VNode, attributes: T::Hash[String, String]).void }
      def set_attributes(node, attributes)
        add_patch(:set_attributes, { node_id: node.id, attributes: })
      end

      sig { params(node: VNode, attributes: T::Array[String]).void }
      def remove_attributes(node, attributes)
        add_patch(:remove_attributes, { node_id: node.id, attributes: })
      end

      sig { returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def to_json
        @patches
      end

      private

      sig { params(type: Symbol, payload: T::Hash[Symbol, T.untyped]).void }
      def add_patch(type, payload)
        patch = { type: }.merge(payload)
        # loc = caller.find { _1.include?("mayu/vdom/") && !_1.include?("patch_set.rb") }.to_s.sub("/Users/andreas/Projects/mayu2/lib/mayu/", "")
        # puts "\e[36m#{loc}\e[0m".ljust(80) + patch.inspect
        @patches.push(patch)
      end
    end
  end
end
