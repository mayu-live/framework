# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module InlineStyle
      # CSS properties which accept numbers but are not in units of "px".
      # Copied from React:
      # https://github.com/facebook/react/blob/a7c57268fb71163e4abb5e386c0d0e63290baaae/packages/react-dom/src/shared/CSSProperty.js
      UNITLESS_PROPERTIES = %i[
        animation_iteration_count
        aspect_ratio
        border_image_outset
        border_image_slice
        border_image_width
        box_flex
        box_flex_group
        box_ordinal_group
        column_count
        columns
        flex
        flex_grow
        flex_positive
        flex_shrink
        flex_negative
        flex_order
        grid_area
        grid_row
        grid_row_end
        grid_row_span
        grid_row_start
        grid_column
        grid_column_end
        grid_column_span
        grid_column_start
        font_weight
        line_clamp
        line_height
        opacity
        order
        orphans
        tab_size
        widows
        z_index
        zoom
        fill_opacity
        flood_opacity
        stop_opacity
        stroke_dasharray
        stroke_dashoffset
        stroke_miterlimit
        stroke_opacity
        stroke_width
      ].freeze

      def self.stringify(properties)
        return properties if properties in String

        properties
          .map do |property, value|
            "#{format_property(property)}:#{format_value(property, value)};"
          end
          .join
      end

      def self.diff(dom_id, old_properties, new_properties)
        old_properties
          .keys
          .union(new_properties.keys)
          .map do |property|
            old_value = old_properties[property]
            new_value = new_properties[property]

            next if old_value == new_value

            unless new_value
              yield(
                Patches::RemoveCSSProperty[dom_id, format_property(property)]
              )
              next
            end

            yield(
              Patches::SetCSSProperty[
                dom_id,
                format_property(property),
                format_value(property, new_value)
              ]
            )
          end
          .compact
      end

      def self.format_property(property)
        property.to_s.tr("_", "-")
      end

      def self.format_value(property, value)
        should_apply_px?(property, value) ? "#{value}px" : value.to_s
      end

      def self.should_apply_px?(property, value)
        return false unless Integer === value
        return false if UNITLESS_PROPERTIES.include?(property)
        return false if property.start_with?("__")
        return false if property.start_with?("--")
        true
      end
    end
  end
end
