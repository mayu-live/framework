# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class VSlot < Base
        def initialize(...)
          super
          @children = VChildren.new(get_children, parent: self)
        end

        def marshal_dump
          [super, @children]
        end

        def marshal_load(a)
          a => [a, children]
          super(a)
          @children = children
        end

        def traverse(&)
          yield self
          @children.traverse(&)
        end

        def child_ids = @children.child_ids

        def start_children = @children.start
        def insert = @children.insert
        def remove = @children.remove
        def render = @children.render

        def update_sync(descriptor)
          @descriptor = descriptor
          @children.update(get_children)
        end

        private

        def get_children
          component = closest(VComponent)
          name = @descriptor.props[:name]
          component.descriptor.children.slots[name]
        end
      end
    end
  end
end
