# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vchildren"
require_relative "vattributes"

module Mayu
  module Runtime
    module VNodes
      class VElement < Base
        VOID_ELEMENTS = %w[
          area
          base
          br
          col
          embed
          hr
          img
          input
          link
          meta
          param
          source
          track
          wbr
        ].freeze

        def initialize(...)
          super

          @children = VChildren.new(@descriptor.children, parent: self)
          @attributes = VAttributes.new(@descriptor, parent: self)
          @tag_name =
            @descriptor.type.to_s.downcase.delete_prefix("__").tr("_", "-")
        end

        attr_reader :tag_name

        def traverse(&)
          yield self
          @children.traverse(&)
        end

        def start
          @children.start
        end

        def stop
          @children.stop
        end

        def update(patches)
        end

        def render_html(out)
          out << "<" << @tag_name
          @attributes.render_html(out)
          out << ">"

          return if VOID_ELEMENTS.include?(@tag_name)

          @children.render_html(out)

          out << "</" << @tag_name << ">"
        end
      end
    end
  end
end
