# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

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

        attr_reader :context

        def start
        end

        def stop
        end

        def update(_patcher)
        end

        def write_html(_out)
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
