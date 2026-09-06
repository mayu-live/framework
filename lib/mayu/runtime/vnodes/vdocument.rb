# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "set"
require_relative "base"
require_relative "patcher"
require_relative "vcomponent"
require_relative "internal_components/html"
require_relative "internal_components/head"

module Mayu
  module Runtime
    module VNodes
      class VDocument < Base
        H = Mayu::Runtime::H
        Html = InternalComponents::Html
        Head = InternalComponents::Head

        def initialize(
          descriptor,
          parent:,
          engine:,
          stylesheets: [],
          scripts: []
        )
          super(descriptor, parent:, engine:)
          @listeners = {}
          @styles = Set.new(stylesheets)
          @scripts = Set.new(scripts)
          @custom_elements = Set.new
          @head = Set.new
          @head_dirty = false
          @html = VComponent.new(init_html, parent: self, engine: @engine)
        end

        def dom_id_tree
          DOM::IdNode[@id, "#document", @html.dom_id_tree]
        end

        def tree_path = [{ name: "#document" }]

        attr_reader :head, :styles, :scripts, :custom_elements

        def update(patcher, descriptor = nil)
          @descriptor = descriptor if descriptor
          @html.update(patcher, init_html)
        rescue VComponent::UnhandledRenderError => e
          emit_render_error(patcher, e.error, e.component)
        end

        def assign_descriptor(descriptor)
          @descriptor = descriptor
        end

        def add_head(vnode)
          @head.add(vnode)
          @head_dirty = true
        end

        def remove_head(vnode)
          @head.delete(vnode)
          @head_dirty = true
        end

        def replace_route_assets(stylesheets:, scripts:)
          styles = Set.new(stylesheets)
          scripts = Set.new(scripts)
          @head_dirty = true if @styles != styles || @scripts != scripts
          @styles = styles
          @scripts = scripts
        end

        def add_custom_element(custom_element)
          @head_dirty = true if @custom_elements.add?(custom_element)
        end

        def add_listener(listener)
          @listeners.store(listener.id, listener)
        end

        def remove_listener(listener)
          @listeners.delete(listener.id)
        end

        def call_listener(id, payload)
          listener =
            @listeners.fetch(id) do
              Console.logger.error(self, "Listener #{id} not found")
              return
            end
          if callback = listener.callback
            metrics.session_callback_count.increment(
              labels: {
                component: component_label_for(callback.component),
                method: callback.method_name
              }
            )
          end

          component = listener.callback&.component
          task = component&.instance_variable_get(:@__vnode_task)
          queue = component&.instance_variable_get(:@__vnode_queue)

          call = -> { listener.call(payload) }

          if task && queue
            queue.enqueue(-> { call_listener_safely(call, listener) })
          elsif task
            task.async { call_listener_safely(call, listener) }
          else
            call_listener_safely(call, listener)
          end
        end

        def flush_head(patcher)
          return unless @head_dirty
          @html.update(patcher, init_html)
          @head_dirty = false
        end

        def head_dirty?
          @head_dirty
        end

        def component_label_for(component)
          label =
            component.class.respond_to?(:module_path) &&
              component.class.module_path
          return label unless label.nil? || label.empty?
          component.class.name
        end

        def start
          @html.start
        end

        def stop
          @html.stop
        end

        def write_html(out)
          @html.update(NullPatcher.new, init_html)
          out << "<!DOCTYPE html>\n"
          @html.write_html(out)
          out << "\n"
        end

        def marshal_dump
          [super, @html, @styles, @scripts, @custom_elements, @listeners]
        end

        def marshal_load(a)
          a => [base, html, styles, scripts, custom_elements, listeners]
          super(base)
          @html = html
          @styles = styles
          @scripts = scripts
          @custom_elements = custom_elements
          @listeners = listeners || {}
          @head = Set.new
          @head_dirty = false
        end

        def rehydrate(parent:, engine:, **)
          super

          component_map = {}
          @html.rehydrate(
            parent: self,
            engine: engine,
            document: self,
            component_map:
          )

          rebuild_head_and_listeners(component_map)
          @listeners.each_value { |listener| listener.rehydrate(component_map) }
          @listeners.delete_if { |_id, listener| listener.callback.nil? }
        end

        def emit_render_error(patcher, error, component_vnode)
          component = component_vnode.instance_variable_get(:@instance)
          tree_path = component_vnode.tree_path
          patch = render_error_patch(error, component, tree_path)
          raise error unless patch
          patcher << patch
        end

        private

        def init_html
          H[Html, init_head, @descriptor]
        end

        def init_head
          H[
            Head,
            runtime_js: @engine.runtime_js,
            styles: @styles,
            scripts: @scripts,
            custom_elements: @custom_elements,
            descriptors: @head.map(&:children).flatten.compact
          ]
        end

        def traverse(&block)
          @html.traverse(&block)
        end

        def rebuild_head_and_listeners(component_map)
          @head.clear

          traverse do |node|
            case node
            when VHead
              @head.add(node)
            when VElement
              node.instance_variable_get(:@attributes).rehydrate_listeners(
                component_map
              )
            end
          end
        end

        def traverse(&block)
          @html.traverse(&block)
        end

        def render_error_patch(error, component, tree_path = [])
          module_path =
            component.class.respond_to?(:module_path) &&
              component.class.module_path
          module_path = component.class.name if module_path.nil? ||
            module_path.empty?

          provider = @engine.module_provider
          mod = Modules::System.current.get_mod(module_path) if module_path &&
            !provider
          formatted_error =
            if provider
              provider.format_exception(error, source_path: module_path)
            else
              Modules::System.current.format_exception(error)
            end
          Console.logger.error(component, formatted_error)

          Patches::RenderError[
            module_path,
            error.class.name,
            error.message,
            error.backtrace,
            mod&.source_map&.input,
            tree_path
          ]
        end

        def call_listener_safely(call, listener)
          call.call
        rescue => e
          component = listener.callback&.component
          component_vnode = find_component_vnode(component)
          tree_path = component_vnode ? component_vnode.tree_path : []
          patch = render_error_patch(e, component, tree_path) if component
          @engine.patch(patch) if patch
        end

        def find_component_vnode(component)
          return nil unless component
          id = component.instance_variable_get(:@__vnode_id)
          return nil unless id

          found = nil
          traverse do |node|
            if node.is_a?(VComponent) && node.id == id
              found = node
              break
            end
          end
          found
        end
      end
    end
  end
end
