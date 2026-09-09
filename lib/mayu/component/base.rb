# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../runtime/h"
require_relative "css_units"
require_relative "fetch"

module Mayu
  module Component
    class Base
      H = Mayu::Runtime::H

      using CSSUnits::Refinements
      include Fetch::Helper

      def self.module_path = nil

      def self.to_s = File.join("MAYU_ROOT", module_path)

      def marshal_dump
        instance_variables
          .reject do |ivar|
            ivar in
              :@__props | :@__context | :@__children | :@__vnode_id |
                :@__vnode_task | :@__vnode_queue
          end
          .map { |ivar| [ivar, instance_variable_get(ivar)] }
          .to_h
      end

      def marshal_load(ivars)
        ivars.each { |ivar, value| instance_variable_set(ivar, value) }
      end

      def mount
      end

      def unmount
      end

      def should_update?(old_props, old_state)
        true
      end

      def render
      end

      attr_reader :__children

      # Klenod's generated slot helper supports frameworks that expose a slot
      # collection through this hook. Mayu keeps the collection on its VDOM
      # descriptor, so this is an adapter rather than a second children model.
      def __slots
        @__children&.slots || {}
      end

      private

      def rerender!
      end

      def update!(value)
        rerender!
        value
      end

      def view_transition
        @__view_transition = true
        yield
      ensure
        @__view_transition = false
      end
    end
  end
end
