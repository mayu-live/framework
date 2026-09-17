# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "base"
require_relative "../dom"
require_relative "../commands"
require_relative "vattributes"
require_relative "vchildren"

module Mayu
  module Runtime
    module VNodes
      class VElement < Base
        def initialize(descriptor, parent:, engine:)
          super
          @children =
            VChildren.new(@descriptor.children, parent: self, engine: @engine)
          @attributes =
            VAttributes.new(@descriptor, parent: self, engine: @engine)
        end

        def update(collector, descriptor = nil)
          return unless descriptor
          # Same object, same attributes and children; see VComponent#unchanged?.
          return if descriptor.equal?(@descriptor) && !@engine&.force_render?

          @descriptor = descriptor
          @attributes.update(collector, @descriptor)
          @children.update(collector, @descriptor.children)
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
          @attributes.remove_listeners
          @children.remove
        end

        def emit_listeners(collector)
          @attributes.each_listener do |name, listener|
            collector << Commands::SetListener[dom_id, name, listener.id]
          end
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

        def write_html_with_id_tree(out, ids)
          tag_name = self.tag_name
          children = []

          out << "<#{tag_name}"
          @attributes.write_html(out)
          out << ">"

          unless Mayu::Runtime::DOM::VOID_ELEMENTS.include?(tag_name)
            @children.write_html_with_id_tree(out, children)
            out << "</#{tag_name}>"
          end

          ids << DOM::IdNode[dom_id, node_name, children]
        end

        def dom_id
          @id
        end

        def collect_id_tree(ids)
          children = []
          @children.collect_id_tree(children)
          ids << DOM::IdNode[dom_id, node_name, children]
        end

        def tree_path
          [*@parent&.tree_path, {name: tag_name}].compact
        end

        def mark_children_dirty
          return if @children_dirty
          @children_dirty = true
          @engine.register_dirty_element(self)
        end

        def emit_replace_children(collector)
          return unless @children_dirty
          child_ids = @children.dom_id_list
          metrics.update_child_id_count.increment(labels: {tag_name:})
          collector << Commands::ReplaceChildren[dom_id, child_ids]
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

        # A vnode never changes type, so the name is computed once. It is
        # used on every render and every id tree walk.
        def tag_name
          @tag_name ||= @descriptor.type.to_s.downcase.delete_prefix("__").tr("_", "-").freeze
        end

        def node_name
          @node_name ||= tag_name.upcase.freeze
        end
      end
    end
  end
end
