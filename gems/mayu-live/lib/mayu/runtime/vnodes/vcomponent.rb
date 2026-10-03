# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "async"
require "async/barrier"

require_relative "base"
require_relative "../marshalling"
require_relative "../../component/state"
require_relative "internal_components/base"
require_relative "../unresolved_component"
require_relative "vchildren"

module Mayu
  module Runtime
    module VNodes
      class VComponent < Base
        class UnhandledRenderError < StandardError
          attr_reader :error, :component

          def initialize(error, component)
            @error = error
            @component = component
            super(error.message)
            set_backtrace(error.backtrace)
          end
        end

        # A component's read-only view of the values provided above it with
        # H.context, read as `@@name`. Values are looked up in the tree when
        # read, so they are the same during rendering and afterwards, for
        # example in event handlers.
        class Context
          class ReadOnlyError < StandardError
          end

          def initialize(node)
            @node = node
          end

          attr_writer :node

          def [](var)
            node = @node&.parent

            while node
              if node.is_a?(VContext) && node.values.key?(var)
                return node.values[var]
              end

              node = node.parent
            end
          end

          def []=(var, _value)
            raise ReadOnlyError,
              "Context is read-only. Provide @@#{var} to a subtree with H.context(#{var}: value) { ... }."
          end

          # The node is set again by VComponent#rehydrate.
          def marshal_dump
            []
          end

          def marshal_load(_)
            @node = nil
          end
        end

        def initialize(descriptor, parent:, engine:)
          super

          @context = Context.new(self)

          @instance = build_instance(@descriptor.type, @descriptor)
          bind_initial_runtime(@instance)
          @mount_task = nil
          @mount_started = false
          @replacing_instance = false
          @handling_render_error = false
          @rerender_requested_during_error = false

          @children = build_initial_children
        end

        private def instance_variables_to_inspect =
          [:@id, @instance, :@children]

        attr_reader :context

        def start
          return if @task

          @task = parent_task&.async do |task|
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
          # stop_instance_work forgets the queue, so read it first.
          queue = @instance.instance_variable_get(:@__vnode_queue)
          stop_instance_work(@instance)
          if queue
            # Handler calls that never ran are cancelled, so callers waiting
            # for them are released.
            while (work = queue.dequeue(timeout: 0))
              work.cancel if work.respond_to?(:cancel)
            end
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

        def update(collector, descriptor = nil)
          return if unchanged?(descriptor)

          replacement_rendered = false
          replacement_children = nil
          skip_render = false
          previous_props = nil

          if descriptor
            previous_type = @descriptor.type

            if previous_type == descriptor.type
              previous_props = @instance.instance_variable_get(:@__props)
              unless @engine&.force_render? || @descriptor.children != descriptor.children
                begin
                  skip_render = !@instance.should_update?(descriptor.props)
                rescue => error
                  raise UnhandledRenderError.new(error, self)
                end
              end
              @descriptor = descriptor
            elsif descriptor.type.equal?(@failed_replacement_type)
              # This class version already failed to replace the instance and
              # the error has been reported. Keep rendering the old instance,
              # with the new props, until hot reload delivers another version.
              @descriptor = descriptor.with(type: previous_type)
            else
              begin
                replacement, replacement_children =
                  prepare_replacement(descriptor.type, descriptor)
              rescue UnhandledRenderError
                @failed_replacement_type = descriptor.type
                raise
              rescue => error
                @failed_replacement_type = descriptor.type
                raise UnhandledRenderError.new(error, self)
              end

              @failed_replacement_type = nil
              replacement_rendered = true
              @descriptor = descriptor
              commit_replacement(replacement)
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

          return if skip_render

          begin
            metrics.update_summary(
              metrics.component_reconcile_duration_ms,
              labels: {
                component: component_label
              }
            ) do
              children =
                replacement_rendered ? replacement_children : render_children
              @children.update(collector, children)
            end
          rescue UnhandledRenderError
            raise
          rescue => error
            raise UnhandledRenderError.new(error, self)
          end

          start_did_update(@instance, previous_props) if previous_props
        end

        # Runs did_update(prev_props) after a parent-driven update has
        # rendered. Like mount, it runs in its own task under the component's
        # task, so it can fetch and write state, and it stops with the
        # component.
        def start_did_update(instance, previous_props)
          return unless @task
          return unless instance.respond_to?(:did_update)

          @task.async { instance.did_update(previous_props) }
        end

        # The same descriptor object means the same props and children. State
        # changes arrive separately through rerender!, and a context change
        # above is forced by its provider, so there is nothing to render.
        def unchanged?(descriptor)
          !descriptor.nil? && descriptor.equal?(@descriptor) && !@engine&.force_render?
        end

        def handle_render_error(error)
          handled = false
          return false unless @instance.respond_to?(:handle_error)

          @handling_render_error = true
          @rerender_requested_during_error = false
          handled = !!@instance.handle_error(error)
          handled
        ensure
          @handling_render_error = false
          if !handled && @rerender_requested_during_error
            @engine.enqueue_update(self)
          end
          @rerender_requested_during_error = false
        end

        def recover_render_error(collector)
          @children.replace(collector, render_children)
        end

        def write_html(out)
          @children.write_html(out)
        end

        def write_html_with_id_tree(out, ids)
          @children.write_html_with_id_tree(out, ids)
        end

        def collect_id_tree(ids)
          @children.collect_id_tree(ids)
        end

        def collect_dom_ids(ids)
          @children.collect_dom_ids(ids)
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

        # The state is a Marshal string of its own, so a restore can decide per
        # component whether to load it: only when none of the modules it came
        # from, the component's own and those of the objects in its state,
        # have changed. `dependencies` maps each module id to its digest.
        def marshal_dump
          component_ref = Marshalling.dump_value(@descriptor.type)
          dependencies = {}
          if component_ref.is_a?(Marshalling::ComponentRef) && component_ref.digest
            dependencies[component_ref.filename] = component_ref.digest
          end
          state = Marshal.dump(Marshalling.dump_value(@instance.marshal_dump, dependencies:))

          [super, component_ref, state, dependencies, @children, @context]
        end

        def marshal_load(a)
          a => [base, component_marshaled, state, dependencies, children, context]
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
          # Loaded or replaced in rehydrate, once context and parents exist.
          @restore = {state:, dependencies:}
          @mount_task = nil
          @mount_started = false
          @replacing_instance = false
          @handling_render_error = false
          @rerender_requested_during_error = false
        end

        def rehydrate(parent:, engine:, document: nil, component_map: nil, **)
          super

          @context.node = self
          restore_instance if @restore
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

        # Restores the transferred state when the code it came from is
        # unchanged. Otherwise, or when the state can not be loaded, starts the
        # component over with its current props and context, and reports why,
        # so it renders again once the engine starts.
        def restore_instance
          restore = @restore
          @restore = nil
          report = @engine.restore_report

          if @descriptor.type == UnresolvedComponent
            report.unresolved!(self, component_label, @descriptor.props[:__unresolved])
            return
          end

          if (reason = changed_dependency(restore[:dependencies]))
            reinitialize_instance(reason)
          else
            @instance.send(:marshal_load, Marshalling.load_value(Marshal.load(restore[:state])))
            @instance.instance_variable_get(:@__state)&.bind(@instance)
            report.restored!
          end
        rescue => error
          reinitialize_instance("#{error.class}: #{error.message}")
        end

        def changed_dependency(dependencies)
          resolver = Fiber[Marshalling::COMPONENT_RESOLVER_KEY]
          return unless resolver.respond_to?(:module_digest)

          dependencies.each do |module_id, digest|
            return "#{module_id} changed" unless resolver.module_digest(module_id) == digest
          end

          nil
        end

        def reinitialize_instance(reason)
          @instance = build_instance(@descriptor.type, @descriptor)
          @engine.restore_report.reinitialized!(self, component_label, reason)
        end

        def build_initial_children
          recovering = false

          begin
            VChildren.new(render_children, parent: self, engine: @engine)
          rescue UnhandledRenderError => failure
            if recovering || failure.component == self
              raise UnhandledRenderError.new(failure.error, self)
            end
            begin
              handled = handle_render_error(failure.error)
            rescue => error
              raise UnhandledRenderError.new(error, self)
            end
            raise unless handled

            recovering = true
            retry
          end
        end

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
          bind_state_runtime(replacement)

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
          instance.define_singleton_method(:__update_interval) do
            vnode.engine.update_interval
          end
          instance.define_singleton_method(:__browser_action) do |name, args|
            vnode.engine.browser_action(name, args)
          end
          bind_state_runtime(instance)
          instance.define_singleton_method(:rerender!) do
            vnode.send(:schedule_rerender, self)
          end
        end

        def bind_initial_runtime(instance)
          bind_runtime(instance, nil, nil)
          instance.singleton_class.send(:private, :rerender!)
        end

        def bind_state_runtime(instance)
          vnode = self
          instance.define_singleton_method(:__before_state_update!) do
            vnode.engine.wait_for_render_completion
          end
          instance.define_singleton_method(:__schedule_state_update!) do
            vnode.send(:schedule_rerender, self) unless
              vnode.engine.state_update_during_render?(self)
          end
        end

        def schedule_rerender(instance)
          if instance.instance_variable_get(:@__view_transition)
            instance_variable_set(
              :@__view_transition_pending,
              instance.instance_variable_get(:@__view_transition)
            )
          end
          if @handling_render_error
            @rerender_requested_during_error = true
          else
            engine.enqueue_update(self)
          end
        end

        def start_mount(instance)
          return unless @task

          @mount_started = true
          @mount_task = @task.async do
            metrics.component_mounts_total.increment(
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
          render_instance(@instance)
        rescue UnhandledRenderError
          raise
        rescue => error
          raise UnhandledRenderError.new(error, self)
        end

        def render_instance(instance)
          engine.with_render_gate do
            metrics.update_summary(
              metrics.component_render_duration_ms,
              labels: {
                component: component_label(instance)
              }
            ) { instance.render }
          end
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
