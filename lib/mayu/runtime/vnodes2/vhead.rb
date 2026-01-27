# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"

module Mayu
  module Runtime
    module VNodes2
      class VHead < Base
        def initialize(descriptor, parent:, engine:)
          super
          add_to_document
        end

        def children = @descriptor.children

        def update(_patcher, descriptor)
          @descriptor = descriptor
        end

        def write_html(_out)
        end

        def insert
          add_to_document
        end

        def remove
          remove_from_document
        end

        private

        def add_to_document
          closest(VDocument)&.add_head(self)
        end

        def remove_from_document
          closest(VDocument)&.remove_head(self)
        end
      end
    end
  end
end
