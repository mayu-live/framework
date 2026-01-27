# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"

module Mayu
  module Runtime
    module VNodes2
      class VAttributes < Base
        def initialize(descriptor, parent:, engine:)
          super
          @attributes = flatten_props(@descriptor.props)
        end

        def update(_patcher)
        end

        def write_html(_out)
        end

        private

        def flatten_props(hash, path = [])
          hash.reduce({}) do |obj, (k, v)|
            next { **obj, k => v } if k == :style && path.empty?

            current_path = [*path, k]

            obj.merge(
              case v
              when Hash
                flatten_props(v, current_path)
              else
                { current_path.join("-").to_sym => v }
              end
            )
          end
        end
      end
    end
  end
end
