# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vbody"
require_relative "vcomment"
require_relative "vcomponent"
require_relative "vcustom_element"
require_relative "velement"
require_relative "vhead"
require_relative "vslot"
require_relative "vstateless"
require_relative "vtext"
require_relative "../../custom_element"

module Mayu
  module Runtime
    module VNodes2
      class VAny < Base
        def initialize(descriptor, parent:, engine:)
          super
          @type = node_type_from_descriptor(@descriptor)
          @child = @type.new(@descriptor, parent: self, engine: @engine)
        end

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
          @child.update(patcher, descriptor)
        end

        def start
          @child.start
        end

        def stop
          @child.stop
        end

        def insert
          @child.insert
        end

        def remove
          @child.remove
        end

        def write_html(out)
          @child.write_html(out)
        end

        def dom_id
          @child.dom_id
        end

        def dom_id_tree
          @child.dom_id_tree
        end

        def traverse(&block)
          yield self
          @child.traverse(&block)
        end

        def marshal_dump
          [super, @child]
        end

        def marshal_load(a)
          a => [base, child]
          super(base)
          @child = child
        end

        def rehydrate(parent:, engine:, **)
          super
          @child.rehydrate(parent: self, engine: engine, **)
        end

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
