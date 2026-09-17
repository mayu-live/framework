# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "base"
require_relative "vbody"
require_relative "vcomment"
require_relative "vcomponent"
require_relative "vcontext"
require_relative "vcustom_element"
require_relative "velement"
require_relative "vhead"
require_relative "vslot"
require_relative "vstateless"
require_relative "vtext"
require_relative "vraw_text"

module Mayu
  module Runtime
    module VNodes
      class VAny < Base
        def initialize(descriptor, parent:, engine:)
          super
          @type = node_type_from_descriptor(@descriptor)
          @child = @type.new(@descriptor, parent: self, engine: @engine)
        end

        def update(collector, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
          @child.update(collector, descriptor)
        end

        def register_custom_element(collector)
          @child.register_custom_element(collector)
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

        def write_html_with_id_tree(out, ids)
          @child.write_html_with_id_tree(out, ids)
        end

        def collect_id_tree(ids)
          @child.collect_id_tree(ids)
        end

        def dom_id
          @child.dom_id
        end

        def dom_ids
          @child.dom_ids
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
          in Descriptors::Element[type: Descriptors::CustomElement]
            VCustomElement
          in Descriptors::Element[type: Class]
            VComponent
          in Descriptors::Element
            VElement
          in Descriptors::Comment
            VComment
          in Descriptors::RawText
            VRawText
          in Descriptors::Context
            VContext
          else
            VText
          end
        end
      end
    end
  end
end
