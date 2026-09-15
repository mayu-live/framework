# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

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
