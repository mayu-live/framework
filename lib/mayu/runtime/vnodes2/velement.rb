# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class VElement < Base
        def initialize(...)
          super
          validate_dom_nesting!

          @children = VChildren.new(@descriptor.children, parent: self)
          @attributes = VAttributes.new(@descriptor, parent: self)
        end

        def marshal_dump
          [super, @children, @attributes]
        end

        def marshal_load(a)
          a => [a, children, attributes]
          super(a)
          @children = children
          @attributes = attributes
        end

        def ancestor_info
          @ancestor_info ||= super.update(@descriptor.type)
        end

        def traverse(&)
          yield self
          @children.traverse(&)
        end

        def child_ids = [@id]

        def start_children
          @children.start
        end

        def insert(patches)
          patches << render.patch_insert
        end

        def remove(patches)
          patches << render.patch_remove
        end

        def render
          tag_name = self.tag_name

          DOM::Element[@id, tag_name, *@children.render, **@attributes.render]
        end

        def update(descriptor)
          @descriptor = descriptor
          @attributes.apply(descriptor)
          @children.apply(descriptor.children)
        end

        def tag_name =
          @descriptor.type.to_s.downcase.delete_prefix("__").tr("_", "-")

        def update_child_ids
          metrics.update_child_id_count.increment(labels: { tag_name: })

          patch(Patches::ReplaceChildren[id, @children.child_ids.flatten])
        end

        private

        def validate_dom_nesting!
          if warning =
               DOMNestingValidation.validate(
                 @descriptor.type,
                 @parent.ancestor_info
               )
            Console.logger.warn(self, warning)
          end
        end
      end
    end
  end
end
