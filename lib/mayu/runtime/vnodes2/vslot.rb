# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vchildren"
require_relative "vcomponent"

module Mayu
  module Runtime
    module VNodes2
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

        def write_html(out)
          @children.write_html(out)
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
