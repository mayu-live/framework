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

        def update(_patcher)
        end

        def write_html(_out)
        end

        private

        def rerender
          @descriptor.type.call(**@descriptor.props)
        end
      end
    end
  end
end
