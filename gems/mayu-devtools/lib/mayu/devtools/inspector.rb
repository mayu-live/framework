# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "mayu/runtime"
require_relative "formatter"
require_relative "recorder"

module Mayu
  module Devtools
    # Answers the queries the devtools extension sends through the session.
    class Inspector
      VNodes = Runtime::VNodes

      def call(engine, query)
        case query
        in {type: "tree"}
          tree(engine)
        in {type: "details", id: String => id}
          details(engine, id)
        in {type: "timings"}
          timings(engine, reset: query[:reset] == true)
        else
          {error: "Unknown query: #{query.inspect}"}
        end
      end

      private

      # Render and callback timings since the devtools first asked, or since
      # the last reset. The first query starts the recording.
      def timings(engine, reset:)
        recorder = Recorder.install(engine)
        recorder.reset if reset

        provider = engine.module_provider
        module_ids = Hash.new { |ids, label| ids[label] = text(module_id(provider, label.to_s)) }

        {
          since: recorder.started_at,
          renders: timing_rows(recorder.timings[:render]) { module_ids[it] },
          reconciles: timing_rows(recorder.timings[:reconcile]) { module_ids[it] },
          callbacks: timing_rows(recorder.timings[:callback]) { |(component, method)| "#{module_ids[component]}##{method}" }
        }
      end

      def timing_rows(timings)
        rows =
          timings.map do |key, timing|
            {
              name: yield(key),
              count: timing.count,
              totalMs: timing.total_ms.round(3),
              maxMs: timing.max_ms.round(3),
              lastMs: timing.last_ms.round(3)
            }
          end
        rows.sort_by { -it[:totalMs] }
      end

      # What the panel shows for the selected node. A component's values are
      # keyed the way Klenod Haml reads them: `$prop`, `@state` and
      # `@@context`.
      def details(engine, id)
        vnode = find_vnode(engine, id)
        return {error: "Node #{id} is not on the page"} unless vnode

        provider = engine.module_provider
        module_ids = Hash.new { |ids, path| ids[path] = module_id(provider, path) }
        lines = Hash.new { |cache, (path, line)| cache[[path, line]] = original_line(provider, path, line) }
        formatter = Formatter.new(
          module_id: ->(path) { module_ids[path] },
          original_line: ->(path, line) { lines[[path, line]] }
        )

        case vnode
        when VNodes::VComponent
          component_details(vnode, formatter)
        when VNodes::VElement
          {
            id:,
            type: "element",
            attributes: formatter.entries(attributes(vnode)),
            handlers: handlers(vnode, formatter)
          }
        else
          {id:, type: "other"}
        end
      end

      def component_details(vnode, formatter)
        instance = vnode.instance_variable_get(:@instance)
        props = instance.instance_variable_get(:@__props) || {}
        state = instance.instance_variable_get(:@__state)&.marshal_dump || {}
        # Components written in Ruby keep their own instance variables.
        ivars =
          (instance.instance_variables - instance.instance_variables.grep(/\A@__/))
            .to_h { [it, instance.instance_variable_get(it)] }

        {
          id: vnode.id,
          type: "component",
          props: formatter.entries(props, prefix: "$"),
          state: formatter.entries(state, prefix: "@"),
          instanceVariables: formatter.entries(ivars),
          context: formatter.entries(context_values(vnode), prefix: "@@"),
          handlers: component_handlers(vnode, formatter)
        }
      end

      # The event handlers of an element: which method each event calls, and
      # where the template refers to it. The block picks callbacks.
      def handlers(element, formatter)
        result = []
        element.each_listener do |event, listener|
          next unless listener.callback
          next if block_given? && !yield(listener.callback)

          result << {
            event: text(event),
            element: text(element.tag_name),
            elementId: element.id,
            handler: formatter.callback_label(listener.callback)
          }
        end
        result
      end

      # The handlers that call the component's methods. They can be on
      # elements it passed to another component as children, so the whole
      # subtree is searched.
      def component_handlers(component, formatter)
        instance = component.instance_variable_get(:@instance)
        result = []
        component.traverse do |vnode|
          next unless vnode.is_a?(VNodes::VElement)
          result.concat(handlers(vnode, formatter) { it.component.equal?(instance) })
        end
        result
      end

      # The values a component can read from its context, with inner values
      # shadowing outer ones. H.context only sets its values while rendering,
      # so they are read from the context vnodes above the component.
      # Components' own `@@name =` assignments stay in their context.
      def context_values(vnode)
        levels = []
        while vnode
          case vnode
          when VNodes::VContext
            levels.unshift(vnode.descriptor.values)
          when VNodes::VComponent
            levels.unshift(vnode.context.marshal_dump.first)
          end
          vnode = vnode.parent
        end
        levels.reduce({}, :merge)
      end

      def attributes(vnode)
        vnode.instance_variable_get(:@attributes).render_for_html.compact.except(:class)
      end

      def find_vnode(engine, id)
        engine.traverse { |vnode| return vnode if vnode.id == id }
        nil
      end

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

      # The template line of a line of compiled code: Klenod evaluates
      # templates as Ruby, so callbacks and procs know compiled lines. The
      # provider's backtrace rewriter maps them through the source maps.
      def original_line(provider, path, line)
        return line unless provider.respond_to?(:rewrite_exception)

        error = StandardError.new
        error.set_backtrace(["#{path}:#{line}:in 'render'"])
        provider.rewrite_exception(error)
        error.backtrace.first[/:(\d+):in /, 1]&.to_i || line
      rescue
        line
      end

      # MessagePack sends binary strings as bytes, which the browser can't
      # show as text.
      def text(value) = Runtime::Commands.utf8(value)
    end
  end
end
