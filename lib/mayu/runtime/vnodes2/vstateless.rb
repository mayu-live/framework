# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vchildren"

module Mayu
  module Runtime
    module VNodes2
      class VStateless < Base
        def initialize(descriptor, parent:, engine:)
          super
          @children = VChildren.new(rerender, parent: self, engine: @engine)
        end

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
          @children.update(patcher, rerender)
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

        def rerender
          @descriptor.type.call(**@descriptor.props)
        end
      end
    end
  end
end
