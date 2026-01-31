# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "../dom"
require_relative "../patches"
require_relative "vattributes"
require_relative "vchildren"

module Mayu
  module Runtime
    module VNodes2
      class VElement < Base
        def initialize(descriptor, parent:, engine:)
          super
          @children =
            VChildren.new(@descriptor.children, parent: self, engine: @engine)
          @attributes =
            VAttributes.new(@descriptor, parent: self, engine: @engine)
        end

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
          @attributes.update(patcher, @descriptor)
          @children.update(patcher, @descriptor.children)
        end

        def start
          @children.start
        end

        def stop
          @children.stop
        end

        def insert
          @children.insert
        end

        def remove
          @children.remove
        end

        def write_html(out)
          tag_name = self.tag_name

          if Mayu::Runtime::DOM::VOID_ELEMENTS.include?(tag_name)
            out << "<#{tag_name}"
            @attributes.write_html(out)
            out << ">"
            return
          end

          out << "<#{tag_name}"
          @attributes.write_html(out)
          out << ">"
          @children.write_html(out)
          out << "</#{tag_name}>"
        end

        def dom_id
          @id
        end

        def dom_id_tree
          DOM::IdNode[
            dom_id,
            tag_name.upcase,
            @children.dom_id_trees.flatten.compact
          ]
        end

        def mark_children_dirty
          return if @children_dirty
          @children_dirty = true
          @engine.register_dirty_element(self)
        end

        def emit_replace_children(patcher)
          return unless @children_dirty
          child_ids = @children.dom_id_list
          metrics.update_child_id_count.increment(labels: { tag_name: })
          patcher << Patches::ReplaceChildren[dom_id, child_ids]
          @children_dirty = false
        end

        def traverse(&block)
          yield self
          @children.traverse(&block)
        end

        def marshal_dump
          [super, @children, @attributes, @children_dirty]
        end

        def marshal_load(a)
          a => [base, children, attributes, children_dirty]
          super(base)
          @children = children
          @attributes = attributes
          @children_dirty = children_dirty
        end

        def rehydrate(parent:, engine:, document: nil, component_map: nil, **)
          super
          @attributes.rehydrate(parent: self, engine: engine)
          @children.rehydrate(
            parent: self,
            engine: engine,
            document:,
            component_map:
          )
          @attributes.rehydrate_listeners(component_map)
        end

        private

        def tag_name
          @descriptor.type.to_s.downcase.delete_prefix("__").tr("_", "-")
        end
      end
    end
  end
end
