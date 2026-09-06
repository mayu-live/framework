# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../style_sheet"
require_relative "../runtime/h"
require_relative "css_units"
require_relative "fetch"
require_relative "style_sheets"

module Mayu
  module Component
    class Base
      H = Mayu::Runtime::H

      using CSSUnits::Refinements
      include Fetch::Helper

      def self.module_path = nil

      def self.to_s = File.join("MAYU_ROOT", module_path)

      def self.merge_props(*sources)
        result =
          sources.reduce do |result, hash|
            result.merge(hash) do |key, old_value, new_value|
              case key
              in :class
                [old_value, new_value].flatten
              else
                new_value
              end
            end
          end

        if classes = result.delete(:class)
          classnames =
            if const_defined?(:ClassNames, false)
              self::ClassNames.class_name(classes)
            else
              self::Styles[*Array(classes).compact]
            end

          result[:class] = classnames unless classnames.nil? ||
            classnames.empty?
        end

        result.transform_keys { _1.to_s.tr("-", "_").to_sym }
      end

      def marshal_dump
        instance_variables
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

      def __children
        @__children
      end

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
