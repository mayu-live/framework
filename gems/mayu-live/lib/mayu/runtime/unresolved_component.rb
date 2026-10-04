# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "../component/base"

module Mayu
  module Runtime
    # Stands in for a component that a transferred session names but the
    # current code can not provide, because its class is gone or its props
    # can not be loaded. It never renders: its closest ancestor renders again
    # once the session resumes, which replaces it.
    class UnresolvedComponent < Mayu::Component::Base
      def render = nil
    end
  end
end
