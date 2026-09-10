# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"
require_relative "base"
require_relative "command_collector"
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

        def tree_path = [{name: "#document"}]

        attr_reader :head, :styles, :scripts, :custom_elements

        def update(collector, descriptor = nil)
          checkpoint = collector.checkpoint
          @descriptor = descriptor if descriptor
          @html.update(collector, init_html)
        rescue VComponent::UnhandledRenderError => failure
          resolve_render_error(collector, failure, checkpoint)
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
              Console.logger.debug(self, "Ignoring stale listener #{id}")
              return
            end
          if (callback = listener.callback)
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

          completion = Async::Queue.new
          call =
            lambda do
              call_listener_safely(-> { listener.call(payload) }, listener)
            ensure
              completion.enqueue(true)
            end

          if task && queue
            queue.enqueue(call)
          elsif task
            task.async(&call)
          else
            call.call
          end

          completion
        end

        def listener_commands
          commands = []
          traverse do |node|
            next unless node.is_a?(VElement)

            attributes = node.instance_variable_get(:@attributes)
            attributes.each_listener do |name, listener|
              commands << Commands::SetListener[node.dom_id, name, listener.id]
            end
          end
          commands
        end

        def rebind_component_instance(vnode_id, instance)
          @listeners.each_value do |listener|
            listener.rebind_component(vnode_id, instance)
          end
        end

        def flush_head(collector)
          return unless @head_dirty
          @html.update(collector, init_html)
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
          update(NullCommandCollector.new)
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

        def resolve_render_error(collector, failure, checkpoint)
          boundary = failure.component.parent&.closest(VComponent)

          while boundary
            begin
              if boundary.handle_render_error(failure.error)
                collector.rollback(checkpoint)
                begin
                  boundary.recover_render_error(collector)
                  return true
                rescue VComponent::UnhandledRenderError => recovery_failure
                  collector.rollback(checkpoint)
                  failure =
                    VComponent::UnhandledRenderError.new(
                      recovery_failure.error,
                      boundary
                    )
                rescue => error
                  collector.rollback(checkpoint)
                  failure = VComponent::UnhandledRenderError.new(error, boundary)
                end
              end
            rescue => error
              failure = VComponent::UnhandledRenderError.new(error, boundary)
            end

            boundary = boundary.parent&.closest(VComponent)
          end

          emit_render_error(collector, failure.error, failure.component)
          false
        end

        def emit_render_error(collector, error, component_vnode)
          component = component_vnode.instance_variable_get(:@instance)
          tree_path = component_vnode.tree_path
          command = render_error_command(error, component, tree_path)
          collector << command if @engine.render_exceptions?
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

        def render_error_command(error, component, tree_path = [])
          module_path =
            component.class.respond_to?(:module_path) &&
            component.class.module_path
          module_path = component.class.name if module_path.nil? ||
            module_path.empty?

          provider = @engine.module_provider
          if provider&.respond_to?(:rewrite_exception)
            provider.rewrite_exception(error)
          end
          formatted_error =
            if provider
              provider.format_exception(error, source_path: module_path)
            else
              error
            end
          Console.logger.error(component, formatted_error)

          Commands::RenderError[
            module_path,
            error.class.name,
            error.message,
            error.backtrace,
            nil,
            tree_path
          ]
        end

        def call_listener_safely(call, listener)
          call.call
        rescue => e
          component = listener.callback&.component
          component_vnode = find_component_vnode(component)
          tree_path = component_vnode ? component_vnode.tree_path : []
          command = render_error_command(e, component, tree_path) if component
          if command && @engine.render_exceptions?
            @engine.enqueue_command(command)
          end
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
