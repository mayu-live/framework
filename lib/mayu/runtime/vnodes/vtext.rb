# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class VText < Base
        def update(descriptor)
          @descriptor = descriptor
        end

        def child_ids = [@id]

        def insert
          patch(render.patch_insert)
        end

        def remove
          patch(render.patch_remove)
        end

        def render
          DOM::Comment[@id, @descriptor.to_s]
        end
      end
    end
  end
end
