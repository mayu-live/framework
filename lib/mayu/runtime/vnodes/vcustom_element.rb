# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class VCustomElement < Base
        def initialize(...)
          super
          custom_element = @descriptor.type
          descriptor = @descriptor.with(type: custom_element.name)
          @element = VElement.new(descriptor, parent: self)

          patch(
            Patches::RegisterCustomElement[
              custom_element.name,
              custom_element.path
            ]
          )
        end

        def traverse(&)
          yield self
          @element.traverse(&)
        end

        def child_ids = @element.child_ids

        def start_children = @element.start_children

        def insert = @element.insert
        def remove = @element.remove
        def render = @element.render

        def update_sync(descriptor)
          @descriptor = descriptor
          @element.update_sync(@descriptor.with(type: @descriptor.type.name))
        end
      end
    end
  end
end
