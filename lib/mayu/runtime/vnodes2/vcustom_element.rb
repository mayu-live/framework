# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "velement"
require_relative "../../custom_element"

module Mayu
  module Runtime
    module VNodes2
      class VCustomElement < Base
        def initialize(descriptor, parent:, engine:)
          super
          custom_element = @descriptor.type
          descriptor = @descriptor.with(type: custom_element.name)
          @element = VElement.new(descriptor, parent: self, engine: @engine)
        end

        def update(_patcher)
        end

        def write_html(_out)
        end

        def dom_id
          @element.dom_id
        end

        def dom_id_tree
          @element.dom_id_tree
        end
      end
    end
  end
end
