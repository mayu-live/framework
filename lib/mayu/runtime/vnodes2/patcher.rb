# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class Patcher
        attr_reader :patches

        def initialize
          @patches = []
        end

        def <<(patch)
          @patches << patch
        end
      end

      class NullPatcher
        def <<(_patch)
        end
      end
    end
  end
end
