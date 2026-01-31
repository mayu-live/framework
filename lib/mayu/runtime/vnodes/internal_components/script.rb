# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "raw_text"

module Mayu
  module Runtime
    module VNodes
      module InternalComponents
        class Script < Base
          def render
            H[:script, H[RawText, content: @__props[:content]], type: "module"]
          end
        end
      end
    end
  end
end
