# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class VStateless < Base
        def initialize(...)
          super
          @children = VChildren.new(rerender, parent: self)
        end

        def marshal_dump
          [*super, @children]
        end

        def marshal_load(a)
          a => [*a, children]
          super(a)
          @children = children
        end

        def insert = @children.insert
        def render = @children.render
        def remove = @children.remove
        def child_ids = @children.child_ids
        def start_children = @children.start_children

        def update_sync(descriptor)
          @descriptor = descriptor
          @children.update(rerender)
        end

        private

        def rerender
          @descriptor.type.call(**@descriptor.props)
        end
      end
    end
  end
end
