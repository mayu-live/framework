# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vattributes"
require_relative "vchildren"

module Mayu
  module Runtime
    module VNodes2
      class VElement < Base
        def initialize(descriptor, parent:, engine:)
          super
          @children =
            VChildren.new(@descriptor.children, parent: self, engine: @engine)
          @attributes =
            VAttributes.new(@descriptor, parent: self, engine: @engine)
        end

        def update(_patcher)
        end

        def write_html(_out)
        end
      end
    end
  end
end
