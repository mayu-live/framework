# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module SilenceIOBufferWarning
    def self.silence_experimental_warning!
      previous = Warning[:experimental]
      Warning[:experimental] = false
      IO::Buffer.new(0) # warning: IO::Buffer is experimental and both the Ruby and C interface may change in the future!
      Warning[:experimental] = previous
    end
  end
end

Mayu::SilenceIOBufferWarning.silence_experimental_warning!
