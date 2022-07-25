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

      sig {void}
      def initialize
        @patches = T.let([], T::Array[T::Hash[Symbol, String]])
      end

      sig {params(parent_node: VNode, new_node: VNode, reference_node: T.nilable(VNode)).void}
      def insert_before(parent_node, new_node, reference_node = nil)
        @patches.push(make_patch(:insert_before, {
          parent_id: parent_node.id,
          reference_id: reference_node&.id,
          html: new_node.inspect_tree,
          ids: new_node.id_tree,
        }))
      end

      sig {params(parent_node: VNode, child_node: VNode).void}
      def remove_child(parent_node, child_node)
        add_patch(:remove_child, {
          parent_id: parent_node.id,
          child_id: child_node.id,
        })
      end

      sig {params(node: VNode, attributes: T::Hash[String, String]).void}
      def set_attributes(node, attributes)
        add_patch(:set_attributes, {
          node_id: node.id,
          attributes:,
        })
      end

      sig {params(node: VNode, attributes: T::Array[String]).void}
      def remove_attributes(node, attributes)
        add_patch(:remove_attributes, {
          node_id: node.id,
          attributes:,
        })
      end

      sig {returns(T::Array[T::Hash[Symbol, T.untyped]])}
      def to_json
        @patches
      end

      private

      sig {params(type: Symbol, payload: T.untyped).void}
      def add_patch(type, payload) = @patches.push(make_patch(type, payload))

      sig {params(type: Symbol, payload: T.untyped).returns(Patch)}
      def make_patch(type, payload) = { type:, payload: }
    end
  end
end
