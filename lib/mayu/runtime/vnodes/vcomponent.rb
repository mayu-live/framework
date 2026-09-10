# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "async/barrier"

require_relative "base"
require_relative "../marshalling"
require_relative "../../component/state"
require_relative "internal_components/base"
require_relative "vchildren"

module Mayu
  module Runtime
    module VNodes
      class VComponent < Base
        class ErrorHandled < StandardError
          attr_reader :boundary

          def initialize(boundary)
            @boundary = boundary
            super()
          end
        end

        class UnhandledRenderError < StandardError
          attr_reader :error, :component

          def initialize(error, component)
            @error = error
            @component = component
            super(error.message)
            set_backtrace(error.backtrace)
          end
        end

        class Context
          def initialize(parent: nil)
            @vars = {}
            @parent = parent
          end

          attr_reader :parent

          def [](var)
            @vars.fetch(var) { @parent[var] if parent }
          end

          def []=(var, value)
            @vars[var] = value
          end

          def with(values)
            previous = {}
            values.each do |key, value|
              previous[key] = @vars.key?(key) ? @vars[key] : :__missing__
              @vars[key] = value
            end

            yield
          ensure
            previous.each do |key, value|
              if value == :__missing__
                @vars.delete(key)
              else
                @vars[key] = value
              end
            end
          end

          def marshal_dump
            [@vars]
          end

          def marshal_load(a)
            @vars = a.first
            @parent = nil
          end
        end

        def initialize(descriptor, parent:, engine:)
          super

          parent_context = @parent.closest(self.class)&.context
          @context = Context.new(parent: parent_context)

          @instance = build_instance(@descriptor.type, @descriptor)
          @mount_task = nil
          @mount_started = false
          @replacing_instance = false

          @children =
            VChildren.new(render_children, parent: self, engine: @engine)
        end

        private def instance_variables_to_inspect =
          [:@id, @instance, :@children]

        attr_reader :context

        def start
          return if @task

          parent_task&.async do |task|
            @task = task
            @instance.instance_variable_set(:@__vnode_task, task)
            queue = Async::Queue.new
            @instance.instance_variable_set(:@__vnode_queue, queue)
            bind_runtime(@instance, task, queue)

            @children.start
            start_mount(@instance)

            loop do
              work = queue.dequeue
              break if work == :__stop__
              Async::Task.current.yield while @replacing_instance
              work.call
            end
          end
        end

        def stop
          return unless @task
          @children.stop
          stop_instance_work(@instance)
          if (queue = @instance.instance_variable_get(:@__vnode_queue))
            queue.enqueue(:__stop__)
          end
          @task.stop
          @task = nil
          @instance.instance_variable_set(:@__vnode_task, nil)
          @instance.instance_variable_set(:@__vnode_queue, nil)
        end

        def insert
          @children.insert
        end

        def remove
          @children.remove
        end

        def update(patcher, descriptor = nil)
          retried = false
          replacement_rendered = false
          replacement_children = nil

          begin
            if descriptor
              previous_type = @descriptor.type

              if previous_type != descriptor.type
                begin
                  replacement, replacement_children =
                    prepare_replacement(descriptor.type, descriptor)
                rescue => error
                  raise UnhandledRenderError.new(error, self)
                end

                replacement_rendered = true
                @descriptor = descriptor
                commit_replacement(replacement)
              else
                @descriptor = descriptor
              end

              @instance.instance_variable_set(
                :@__children,
                @descriptor.children.freeze
              )
              @instance.instance_variable_set(
                :@__props,
                @descriptor.props.freeze
              )
            end

            metrics.update_summary(
              metrics.component_children_update_times,
              labels: {
                component: component_label
              }
            ) do
              children =
                replacement_rendered ? replacement_children : render_children
              @children.update(patcher, children)
            end
          rescue ErrorHandled => e
            raise if retried || e.boundary != self
            retried = true
            replacement_rendered = false
            replacement_children = nil
            retry
          end
        end

        def write_html(out)
          @children.write_html(out)
        end

        def write_html_with_id_tree(out)
          @children.write_html_with_id_tree(out)
        end

        def dom_id_tree
          @children.dom_id_tree
        end

        def tree_path
          node = {name: component_label}
          path = @instance.class.module_path
          if path && !path.empty?
            node[:path] = path
            class_name = @instance.class.name
            node[:name] = (
              if class_name
                class_name.split("::").last
              else
                component_label
              end
            )
          end

          [*@parent&.tree_path, node].compact
        end

        def traverse(&block)
          yield self
          @children.traverse(&block)
        end

        def marshal_dump
          [
            super,
            Marshalling.dump_value(@descriptor.type),
            Marshalling.dump_value(@instance.marshal_dump),
            @children,
            @context
          ]
        end

        def marshal_load(a)
          a => [base, component_marshaled, component_state, children, context]
          super(base)
          component_class =
            Marshalling.load_value(
              component_marshaled,
              fallback_class: @descriptor.type
            )

          @descriptor = @descriptor.with(type: component_class)
          @context = context
          @children = children

          @instance = component_class.allocate
          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)
          @instance.instance_variable_set(:@__context, @context)
          @instance.instance_variable_set(
            :@__children,
            @descriptor.children.freeze
          )
          @instance.instance_variable_set(:@__vnode_id, @id)
          @instance.send(:marshal_load, Marshalling.load_value(component_state))
          @instance.instance_variable_get(:@__state)&.bind(@instance)
          @mount_task = nil
          @mount_started = false
          @replacing_instance = false
        end

        def rehydrate(parent:, engine:, document: nil, component_map: nil, **)
          super

          parent_context = @parent&.closest(self.class)&.context
          @context.instance_variable_set(:@parent, parent_context)
          @instance.instance_variable_set(:@__context, @context)
          @instance.instance_variable_get(:@__state)&.bind(@instance)
          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)
          @instance.instance_variable_set(
            :@__children,
            @descriptor.children.freeze
          )

          component_map[@id] = @instance if component_map
          @children.rehydrate(
            parent: self,
            engine: engine,
            document:,
            component_map:
          )
        end

        private

        def build_instance(klass, descriptor)
          instance = klass.allocate
          install_descriptor_state(instance, descriptor)
          instance.instance_variable_set(
            :@__state,
            Mayu::Component::State.new(instance)
          )
          instance.send(:initialize)
          instance
        end

        def install_descriptor_state(instance, descriptor)
          instance.instance_variable_set(:@__props, descriptor.props.freeze)
          instance.instance_variable_set(:@__context, @context)
          instance.instance_variable_set(
            :@__children,
            descriptor.children.freeze
          )
          instance.instance_variable_set(:@__vnode_id, @id)
        end

        def prepare_replacement(klass, descriptor)
          old_instance = @instance
          replacement = build_instance(klass, descriptor)

          begin
            component_dump =
              @engine.migrate_component_state(old_instance.marshal_dump)
            component_dump =
              merge_initialized_state(replacement, component_dump)
            replacement.send(:marshal_load, component_dump)
          rescue => error
            Console.logger.warn(
              self,
              "Could not preserve component state during HMR: #{error.message}"
            )
            replacement = build_instance(klass, descriptor)
          end

          install_descriptor_state(replacement, descriptor)
          state = replacement.instance_variable_get(:@__state)
          unless state.is_a?(Mayu::Component::State)
            state = Mayu::Component::State.new(replacement)
            replacement.instance_variable_set(:@__state, state)
          end
          state.bind(replacement)

          [replacement, render_instance(replacement)]
        end

        def commit_replacement(replacement)
          old_instance = @instance
          task = old_instance.instance_variable_get(:@__vnode_task)
          queue = old_instance.instance_variable_get(:@__vnode_queue)
          @replacing_instance = true
          begin
            if task
              begin
                stop_instance_work(old_instance)
              rescue => error
                Console.logger.warn(
                  self,
                  "Could not clean up component during HMR: #{error.message}"
                )
              end
            end

            @instance = replacement
            if task && queue
              bind_runtime(replacement, task, queue)
              @engine.rebind_component_instance(@id, replacement)
              start_mount(replacement)
            end
          ensure
            @replacing_instance = false
          end
        end

        def merge_initialized_state(instance, component_dump)
          return component_dump unless component_dump.is_a?(Hash)

          initialized_state = instance.instance_variable_get(:@__state)
          restored_state = component_dump[:@__state]
          unless initialized_state.is_a?(Mayu::Component::State) &&
              restored_state.is_a?(Mayu::Component::State)
            return component_dump
          end

          initialized_state.send(
            :marshal_load,
            initialized_state.marshal_dump.merge(restored_state.marshal_dump)
          )
          component_dump.merge(:@__state => initialized_state)
        end

        def bind_runtime(instance, task, queue)
          instance.instance_variable_set(:@__vnode_task, task)
          instance.instance_variable_set(:@__vnode_queue, queue)

          vnode = self
          instance.define_singleton_method(:rerender!) do
            if @__view_transition
              vnode.instance_variable_set(:@__view_transition_pending, true)
            end
            vnode.engine.enqueue_update(vnode)
          end
        end

        def start_mount(instance)
          return unless @task

          @mount_started = true
          @mount_task = @task.async do
            metrics.component_mount_count.increment(
              labels: {
                component: component_label
              }
            )
            instance.mount
          end
        end

        def stop_instance_work(instance)
          @mount_task&.stop
          @mount_task = nil
          if @mount_started
            instance.unmount
            @mount_started = false
          end
          instance.instance_variable_set(:@__vnode_task, nil)
          instance.instance_variable_set(:@__vnode_queue, nil)
        end

        def render_children
          retried = false

          begin
            render_instance(@instance)
          rescue ErrorHandled => e
            raise if retried
            retried = true

            if e.boundary == self
              retry
            else
              raise
            end
          rescue => e
            raise if retried
            retried = true

            boundary = handle_error_up_tree(e)

            if boundary
              if boundary == self
                retry
              else
                raise ErrorHandled, boundary
              end
            else
              raise UnhandledRenderError.new(e, self)
            end
          end
        end

        def render_instance(instance)
          metrics.update_summary(
            metrics.component_patch_times,
            labels: {
              component: component_label(instance)
            }
          ) { instance.render }
        end

        def handle_error_up_tree(error)
          node = self

          while node
            instance = node.instance_variable_get(:@instance)
            if instance.respond_to?(:handle_error)
              handled = instance.handle_error(error)
              return node if handled
            end

            node = node.parent&.closest(VComponent)
          end

          nil
        end

        def component_label(instance = @instance)
          label =
            instance.class.respond_to?(:module_path) &&
            instance.class.module_path
          return label unless label.nil? || label.empty?
          instance.class.name
        end
      end
    end
  end
end
