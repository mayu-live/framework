require_relative "../style_sheet"
require_relative "../runtime/h"
require_relative "css_units"

module Mayu
  module Component
    class Base
      H = Mayu::Runtime::H

      using CSSUnits::Refinements

      def self.init(**props)
        component = allocate
        component.instance_variable_set(:@__props, props)
        component.send(:initialize)
        component
      end

      def self.module_path
      end

      def self.import(filename) =
        Modules::System.import(filename, caller.first.split(":", 2).first)

      def self.import?(filename) =
        Modules::System.import?(filename, caller.first.split(":", 2).first)

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
          classnames = self::Styles[*Array(classes).compact]

          result[:class] = classnames.join(" ") unless classnames.empty?
        end

        result
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

      private

      def rerender!
      end

      def update!(value)
        rerender!
        value
      end
    end
  end
end
