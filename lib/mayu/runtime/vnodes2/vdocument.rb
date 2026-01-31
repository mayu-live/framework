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
    module VNodes2
      class VDocument < Base
        H = Mayu::Runtime::H
        Html = InternalComponents::Html
        Head = InternalComponents::Head

        def initialize(descriptor, parent:, engine:)
          super
          @listeners = {}
          @styles = Set.new
          @head = Set.new
          @head_dirty = false
          @html = VComponent.new(init_html, parent: self, engine: @engine)
        end

        def dom_id_tree
          DOM::IdNode[@id, "#document", @html.dom_id_tree]
        end

        attr_reader :head, :styles

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

        def add_stylesheet(filename)
          @head_dirty = true if @styles.add?(filename)
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
          [super, @html, @styles]
        end

        def marshal_load(a)
          a => [base, html, styles]
          super(base)
          @html = html
          @styles = styles
          @head = Set.new
          @listeners = {}
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
        end

        def emit_render_error(patcher, error, component_vnode)
          component = component_vnode.instance_variable_get(:@instance)
          patch = render_error_patch(error, component)
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
            descriptors: @head.map(&:children).flatten.compact
          ]
        end

        def traverse(&block)
          @html.traverse(&block)
        end

        def rebuild_head_and_listeners(component_map)
          @head.clear
          @listeners.clear

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

        def render_error_patch(error, component)
          module_path =
            component.class.respond_to?(:module_path) &&
              component.class.module_path
          module_path = component.class.name if module_path.nil? ||
            module_path.empty?

          mod = Modules::System.current.get_mod(module_path) if module_path
          puts Modules::System.current.format_exception(error)

          Patches::RenderError[
            module_path,
            error.class.name,
            error.message,
            error.backtrace,
            mod&.source_map&.input,
            []
          ]
        end

        def call_listener_safely(call, listener)
          call.call
        rescue => e
          component = listener.callback&.component
          patch = render_error_patch(e, component) if component
          @engine.patch(patch) if patch
        end
      end
    end
  end
end
