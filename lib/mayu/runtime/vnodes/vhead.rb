# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class VHead < Base
        def initialize(...)
          super
          add_to_document
        end

        def traverse
          yield self
        end

        def insert = add_to_document
        def remove = remove_from_document
        def render = nil
        def start_children = nil
        def child_ids = []

        def children = @descriptor.children

        def update_sync(descriptor)
          unless @descriptor.children == descriptor.children
            @descriptor = descriptor
            add_to_document
          end
        end

        private

        def add_to_document
          closest(VDocument).add_head(self)
        end

        def remove_from_document
          closest(VDocument).remove_head(self)
        end
      end
    end
  end
end
