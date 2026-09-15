# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "../../descriptors"

module Mayu
  module Runtime
    module VNodes
      module InternalComponents
        class RawText < Base
          def render
            Descriptors::RawText[@__props[:content].to_s]
          end
        end
      end
    end
  end
end
