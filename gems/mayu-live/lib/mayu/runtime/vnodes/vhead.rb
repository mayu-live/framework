# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "base"

module Mayu
  module Runtime
    module VNodes
      class VHead < Base
        def initialize(descriptor, parent:, engine:)
          super
          add_to_document
        end

        def children = @descriptor.children

        # Only a change in content is worth a head flush. A parent that
        # re-renders hands every head node a fresh descriptor, usually with
        # the same title and tags as before.
        def update(_command_collector, descriptor)
          changed = @descriptor != descriptor
          @descriptor = descriptor
          closest(VDocument)&.mark_head_dirty if changed
        end

        def write_html(_out)
        end

        def marshal_dump
          [super, @children]
        end

        def marshal_load(a)
          a => [base, children]
          super(base)
          @children = children
        end

        def rehydrate(parent:, engine:, **)
          super
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
