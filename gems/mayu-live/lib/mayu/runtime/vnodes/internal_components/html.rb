# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "base"

module Mayu
  module Runtime
    module VNodes
      module InternalComponents
        class Html < Base
          def render
            H[:html, H[:slot]]
          end
        end
      end
    end
  end
end
