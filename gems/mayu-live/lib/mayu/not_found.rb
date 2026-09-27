# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  # Raised from a component's render to show the closest +not-found view for
  # the current path, as if the route had not matched. It is control flow
  # rather than an error: error boundaries do not see it, and nothing is
  # logged or shown in the overlay.
  class NotFound < StandardError
    def initialize(message = "Not found")
      super
    end
  end
end
