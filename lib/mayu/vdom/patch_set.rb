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

      sig { params(id: Integer, text: String).void }
      def update_text(id, text)
        add_patch(:update_text, { id:, text: })
      end

      sig { params(id: Integer, name: String, value: String).void }
      def set_attribute(id, name, value)
        add_patch(:set_attribute, { id:, name:, value: })
      end

      sig { params(id: Integer, name: String).void }
      def remove_attribute(id, name)
        add_patch(:remove_attribute, { id:, name: })
      end

      sig do
        params(
          parent_id: Integer,
          new_node: VNode,
          reference_id: T.nilable(Integer)
        ).void
      end
      def insert_before(parent_id, new_node, reference_id = nil)
        add_patch(
          :insert_before,
          {
            parent_id:,
            reference_id:,
            html: new_node.inspect_tree,
            ids: new_node.id_tree
          }
        )
      end

      sig { params(id: Integer).void }
      def remove_node(id)
        add_patch(:remove_node, { id: })
      end

      sig { params(parent_id: Integer, child_id: Integer).void }
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
        @patches.push(patch)
      end
    end
  end
end
