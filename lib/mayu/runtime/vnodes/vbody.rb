# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "velement"

module Mayu
  module Runtime
    module VNodes
      class VBody < VElement
        def initialize(descriptor, parent:)
          super(inject_mayu_ping(descriptor), parent:)
        end

        def update_sync(descriptor)
          super(inject_mayu_ping(descriptor))
        end

        private

        def inject_mayu_ping(descriptor)
          descriptor.with(
            children: [*descriptor.children, H[:mayu_ping, ping: "N/A"]]
          )
        end
      end
    end
  end
end
