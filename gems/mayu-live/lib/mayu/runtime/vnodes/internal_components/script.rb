# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
