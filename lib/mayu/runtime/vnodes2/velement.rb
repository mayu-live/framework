# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "cgi"
require_relative "base"
require_relative "../dom"
require_relative "../inline_style"
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
          attributes = render_attributes

          if Mayu::Runtime::DOM::VOID_ELEMENTS.include?(tag_name)
            out << "<#{tag_name}#{attributes}>"
            return
          end

          out << "<#{tag_name}#{attributes}>"
          @children.write_html(out)
          out << "</#{tag_name}>"
        end

        def dom_id
          @id
        end

        def dom_id_tree
          children = @children.dom_id_trees.flatten.compact
          DOM::IdNode[dom_id, tag_name.upcase, children]
        end

        def mark_children_dirty
          return if @children_dirty
          @children_dirty = true
          @engine.register_dirty_element(self)
        end

        def emit_replace_children(patcher)
          return unless @children_dirty
          child_ids = @children.dom_id_list
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
          @attributes.rehydrate_listeners(document, component_map) if document
        end

        private

        def tag_name
          @descriptor.type.to_s.downcase.delete_prefix("__").tr("_", "-")
        end

        def render_attributes
          attributes = @descriptor.props || {}
          internal = Mayu::Runtime::DOM::INJECT_MAYU_ID ? { mayu_id: @id } : {}

          (internal.merge(attributes))
            .except(:slot)
            .map do |attr, value|
              next if value.nil?

              if attr == :style && value.is_a?(Hash)
                value = InlineStyle.stringify(value)
              end

              value = value.join(" ") if attr == :class && value.is_a?(Array)

              rendered_value =
                if value.respond_to?(:to_js)
                  value.to_js
                else
                  CGI.escape_html(value.to_s)
                end

              name = CGI.escape_html(attr.to_s.tr("_", "-"))
              format(' %s="%s"', name, rendered_value)
            end
            .compact
            .join
        end
      end
    end
  end
end
