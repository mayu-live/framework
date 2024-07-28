# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../../custom_element"

module Mayu
  module Runtime
    module VNodes
      class VAny < Base
        def initialize(...)
          super
          @type = node_type_from_descriptor(@descriptor)
          @child = @type.new(@descriptor, parent: self)
          # puts "Creating #{@type} for #{@descriptor}"
        end

        def marshal_dump
          [super, @type, @child]
        end

        def marshal_load(a)
          a => [a, type, child]
          super(a)
          @type = type
          @child = child
        end

        def traverse(&)
          yield self
          @child.traverse(&)
        end

        def child_ids = @child.child_ids

        def insert = @child.insert
        def remove = @child.remove
        def render = @child.render

        def start_children = @child.start
        def update_sync(descriptor) = @child.update(descriptor)

        private

        def node_type_from_descriptor(descriptor)
          case descriptor
          in Descriptors::Element[type: :slot]
            VSlot
          in Descriptors::Element[type: :head]
            VHead
          in Descriptors::Element[type: :body]
            VBody
          in Descriptors::Element[type: Proc]
            VStateless
          in Descriptors::Element[type: CustomElement]
            VCustomElement
          in Descriptors::Element[type: Class]
            VComponent
          in Descriptors::Element
            VElement
          in Descriptors::Comment
            VComment
          else
            VText
          end
        end
      end
    end
  end
end
