# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

      # Components are labelled by their source path. In development that
      # path is absolute, so it is shown relative to the app root, which is
      # the working directory while the server runs.
      def self.to_s
        path = module_path
        return super if path.nil? || path.empty?
        return path unless File.absolute_path?(path)

        path.delete_prefix("#{Dir.pwd}/")
      end

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
