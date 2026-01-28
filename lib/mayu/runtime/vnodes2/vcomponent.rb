# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"

require_relative "base"
require_relative "internal_components/base"
require_relative "vchildren"

module Mayu
  module Runtime
    module VNodes2
      class VComponent < Base
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
          klass = @descriptor.type

          if mod = get_mod
            vdocument = closest(VDocument)
            find_stylesheets(mod).each do |filename|
              vdocument.add_stylesheet(filename)
            end
          end

          parent_context = @parent.closest(self.class)&.context
          @context = Context.new(parent: parent_context)

          @instance = klass.allocate
          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)
          @instance.instance_variable_set(:@__context, @context)
          @instance.instance_variable_set(
            :@__children,
            @descriptor.children.freeze
          )
          @instance.instance_variable_set(:@__vnode_id, @id)
          @instance.send(:initialize)

          @children =
            VChildren.new(render_children, parent: self, engine: @engine)
        end

        private def instance_variables_to_inspect =
          [:@id, @instance, :@children]

        attr_reader :context

        def start
          parent_task&.async do |task|
            @task = task

            vnode = self
            @instance.define_singleton_method(:rerender!) do
              vnode.engine.enqueue_update(vnode)
            end

            @children.start
            @instance.mount
          end
        end

        def stop
          @children.stop
          @task&.stop
          @task = nil
          @instance.unmount
        end

        def insert
          @children.insert
        end

        def remove
          @children.remove
        end

        def update(patcher, descriptor = nil)
          if descriptor
            @descriptor = descriptor

            @instance.instance_variable_set(
              :@__children,
              @descriptor.children.freeze
            )
            @instance.instance_variable_set(:@__props, @descriptor.props.freeze)
          end

          @children.update(patcher, render_children)
        end

        def write_html(out)
          @children.write_html(out)
        end

        def dom_id_tree
          @children.dom_id_tree
        end

        def traverse(&block)
          yield self
          @children.traverse(&block)
        end

        def marshal_dump
          [
            super,
            @descriptor.type.module_path,
            @descriptor.type.name,
            @instance.marshal_dump,
            @children,
            @context
          ]
        end

        def marshal_load(a)
          a => [
            base,
            component_module_path,
            component_class_name,
            component_state,
            children,
            context
          ]
          super(base)

          @context = context
          @children = children

          klass =
            resolve_component_class(component_module_path, component_class_name)

          @instance = klass.allocate
          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)
          @instance.instance_variable_set(:@__context, @context)
          @instance.instance_variable_set(
            :@__children,
            @descriptor.children.freeze
          )
          @instance.instance_variable_set(:@__vnode_id, @id)
          @instance.send(:marshal_load, component_state)
        end

        def rehydrate(parent:, engine:, document: nil, component_map: nil, **)
          super

          parent_context = @parent&.closest(self.class)&.context
          @context.instance_variable_set(:@parent, parent_context)
          @instance.instance_variable_set(:@__context, @context)
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

        def render_children
          @instance.render
        end

        def resolve_component_class(module_path, class_name)
          if module_path.nil?
            return @descriptor.type if @descriptor.type.is_a?(Class)
            raise "Missing component module_path for #{@descriptor.inspect}"
          end

          if module_path.start_with?("(internal)::")
            return InternalComponents.const_get(class_name)
          end

          mod = Modules::System.current.get_mod(module_path)
          exports = mod.const_get(:Exports)
          exports.const_get(class_name)
        end

        def get_mod(module_path = @descriptor.type.module_path)
          if module_path.nil? || module_path.start_with?("(internal)")
            nil
          else
            Modules::System.current.get_mod(module_path)
          end
        end

        def find_stylesheets(mod)
          [
            mod.assets.select do |filename|
              filename.sub(/\?[^?]*$/, "").end_with?(".css")
            end,
            mod
              .dependencies
              .select { |path| path.end_with?(".css") }
              .map { |path| find_stylesheets(get_mod(path)) }
          ].flatten.compact
        end
      end
    end
  end
end
