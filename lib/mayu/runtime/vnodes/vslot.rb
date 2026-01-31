# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vchildren"
require_relative "vcomponent"

module Mayu
  module Runtime
    module VNodes
      class VSlot < Base
        def initialize(descriptor, parent:, engine:)
          super
          @children = VChildren.new(get_children, parent: self, engine: @engine)
        end

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
          @children.update(patcher, get_children)
        end

        def start
          @children.start
        end

        def stop
          @children.stop
        end

        def insert
          @children.insert
        end

        def remove
          @children.remove
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
          [super, @children]
        end

        def marshal_load(a)
          a => [base, children]
          super(base)
          @children = children
        end

        def rehydrate(parent:, engine:, **)
          super
          @children.rehydrate(parent: self, engine: engine, **)
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
