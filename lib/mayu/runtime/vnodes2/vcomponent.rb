# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"

require_relative "base"
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
        end

        def initialize(descriptor, parent:, engine:)
          super
          klass = @descriptor.type
          parent_context = @parent.closest(self.class)&.context
          @context = Context.new(parent: parent_context)

          @instance = klass.allocate
          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)
          @instance.instance_variable_set(:@__context, @context)
          @instance.instance_variable_set(
            :@__children,
            @descriptor.children.freeze
          )
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

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor

          @instance.instance_variable_set(
            :@__children,
            @descriptor.children.freeze
          )
          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)

          @children.update(patcher, render_children)
        end

        def write_html(out)
          @children.write_html(out)
        end

        def dom_id_tree
          @children.dom_id_tree
        end

        private

        def render_children
          @instance.render
        end
      end
    end
  end
end
