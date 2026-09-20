# frozen_string_literal: true

module Mayu
  module Test
    class ComponentQueryError < QueryError
    end

    class ComponentNotFoundError < ComponentQueryError
    end

    class MultipleComponentsFoundError < ComponentQueryError
    end

    class ComponentHandle
      def initialize(vnode)
        @vnode = vnode
      end

      def props = @vnode.descriptor.props

      def state(name)
        instance!
          .instance_variable_get(:@__state)
          &.[](name.to_s.delete_prefix("@").to_sym)
      end

      # Accessing component methods is useful for deterministic unit tests,
      # but should not replace assertions on user-observable behavior.
      def instance! = @vnode.instance_variable_get(:@instance)
    end
  end
end
