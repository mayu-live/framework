# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  module WarningFilter
    IO_BUFFER_EXPERIMENTAL_WARNING = "IO::Buffer is experimental"

    def warn(message, category: nil, **kwargs)
      return if message.to_s.include?(IO_BUFFER_EXPERIMENTAL_WARNING)

      super
    end
  end
end

Warning.extend Mayu::WarningFilter
