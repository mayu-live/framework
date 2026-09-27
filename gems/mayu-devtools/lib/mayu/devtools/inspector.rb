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
        provider = engine.module_provider
        module_ids = Hash.new { |ids, path| ids[path] = module_id(provider, path) }
        source_classes = Hash.new { |maps, klass| maps[klass] = source_class_map(klass) }.compare_by_identity

        engine.traverse do |vnode|
          node = serialize(vnode, module_ids, source_classes)
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

      def serialize(vnode, module_ids, source_classes)
        case vnode
        when VNodes::VComponent
          component(vnode, module_ids)
        when VNodes::VStateless
          stateless(vnode)
        when VNodes::VElement
          element(vnode, source_classes)
        end
      end

      def element(vnode, source_classes)
        rendered = vnode.instance_variable_get(:@attributes).render_for_html[:class]
        classes =
          Array(rendered).map do |class_name|
            source = source_class_name(vnode, class_name, source_classes)
            # Klenod scopes a component's tag selectors, such as `a { ... }`,
            # with a class named after the tag: `__a`. It isn't in the source.
            if source&.start_with?("__")
              {source: nil, rendered: text(class_name), scope: true}
            else
              {source: source && text(source), rendered: text(class_name), scope: false}
            end
          end

        {id: vnode.id, type: "element", name: vnode.tag_name, classes:, children: []}
      end

      # The name a class has in the source, such as `title` for `%a.title`.
      # Klenod turns those into generated class names through the ClassNames
      # of the component. Slotted content is written in an outer component, so
      # its classes are looked up further out.
      def source_class_name(vnode, class_name, source_classes)
        component = vnode.parent&.closest(VNodes::VComponent)

        while component
          klass = component.instance_variable_get(:@instance).class
          source = source_classes[klass][class_name]
          return source if source

          component = component.parent&.closest(VNodes::VComponent)
        end
      end

      # Generated class names to source names, from the ClassNames constant
      # Klenod defines on each component class.
      def source_class_map(klass)
        return {} unless klass.const_defined?(:ClassNames, false)

        class_names = klass.const_get(:ClassNames, false)
        return {} unless class_names.respond_to?(:each_pair)

        map = {}
        class_names.each_pair do |source, generated|
          generated.to_s.split.each { map[it] ||= source.to_s }
        end
        map
      end

      def component(vnode, module_ids)
        instance = vnode.instance_variable_get(:@instance)
        klass = instance.class
        path = klass.module_path if klass.respond_to?(:module_path)
        path = (path && !path.empty?) ? module_ids[path] : nil
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

      # The Klenod module id of a component's source file, such as
      # app:/components/Header.haml, which is shorter than the absolute path.
      # Mayu's own components, and paths the provider can't resolve, keep
      # their path. Providers raise KeyError or their own resolve errors.
      def module_id(provider, path)
        return path if provider.nil? || path.start_with?("(internal)::")

        provider.module_id_for(path).to_s
      rescue
        path
      end

      # MessagePack sends binary strings as bytes, which the browser can't
      # show as text.
      def text(value) = Runtime::Commands.utf8(value)
    end
  end
end
