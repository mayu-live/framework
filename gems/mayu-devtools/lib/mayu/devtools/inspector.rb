# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "mayu/runtime"

module Mayu
  module Devtools
    # Answers the queries the devtools extension sends through the session.
    class Inspector
      VNodes = Runtime::VNodes

      def call(engine, query)
        case query
        in {type: "tree"}
          tree(engine)
        else
          {error: "Unknown query: #{query.inspect}"}
        end
      end

      private

      # The components and elements of the page. Wrapper vnodes such as
      # children lists, contexts and slots are left out, so every node is
      # nested under its closest component or element. Element ids are DOM
      # ids, which the browser runtime maps to DOM nodes.
      def tree(engine)
        document = {id: engine.root.id, type: "document", name: "#document", children: []}
        nodes = {}.compare_by_identity

        engine.traverse do |vnode|
          node = serialize(vnode)
          next unless node

          nodes[vnode] = node
          (closest_node(vnode.parent, nodes) || document)[:children] << node
        end

        document
      end

      def closest_node(vnode, nodes)
        while vnode
          node = nodes[vnode]
          return node if node
          vnode = vnode.parent
        end
      end

      def serialize(vnode)
        case vnode
        when VNodes::VComponent
          component(vnode)
        when VNodes::VStateless
          stateless(vnode)
        when VNodes::VElement
          {id: vnode.id, type: "element", name: vnode.tag_name, children: []}
        end
      end

      def component(vnode)
        instance = vnode.instance_variable_get(:@instance)
        klass = instance.class
        path = klass.module_path if klass.respond_to?(:module_path)
        path = nil if path && path.empty?
        name = klass.name&.split("::")&.last || path || "(anonymous)"

        {
          id: vnode.id,
          type: "component",
          name: text(name),
          path: path && text(path),
          internal: instance.is_a?(VNodes::InternalComponents::Base),
          children: []
        }
      end

      def stateless(vnode)
        type = vnode.descriptor.type
        name = type.respond_to?(:name) && type.name
        file, line = type.source_location if type.respond_to?(:source_location)

        {
          id: vnode.id,
          type: "component",
          name: text(name || "(stateless)"),
          path: file && text("#{file}:#{line}"),
          internal: false,
          children: []
        }
      end

      # MessagePack sends binary strings as bytes, which the browser can't
      # show as text.
      def text(value) = Runtime::Commands.utf8(value)
    end
  end
end
