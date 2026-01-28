# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"

module Mayu
  module Runtime
    module VNodes2
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
