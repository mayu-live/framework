# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "velement"

module Mayu
  module Runtime
    module VNodes2
      class VBody < VElement
        H = Mayu::Runtime::H

        def initialize(descriptor, parent:, engine:)
          super(inject_mayu_ping(descriptor), parent:, engine:)
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
