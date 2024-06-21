# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class VComment < Base
        def update_sync(descriptor)
          @descriptor = descriptor
        end

        def child_ids = [@id]

        def insert
          patch(render.patch_insert)
        end

        def render
          DOM::Comment[@id, @descriptor.to_s]
        end
      end
    end
  end
end
