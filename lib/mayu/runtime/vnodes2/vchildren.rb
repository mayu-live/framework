# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"

module Mayu
  module Runtime
    module VNodes2
      class VChildren < Base
        def initialize(descriptor, parent:, engine:)
          super
        end

        def update(_patcher)
        end

        def write_html(_out)
        end
      end
    end
  end
end
