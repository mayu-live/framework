# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Utils
    module DeepFreeze
      def self.deep_freeze(obj)
        case obj
        when Hash
          obj
            .transform_keys { deep_freeze(it) }
            .transform_values { deep_freeze(it) }
            .freeze
        when Array
          obj.map { |elem| deep_freeze(elem) }.freeze
        else
          obj.freeze
        end
      end
    end
  end
end
