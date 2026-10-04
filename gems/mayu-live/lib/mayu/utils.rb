# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
