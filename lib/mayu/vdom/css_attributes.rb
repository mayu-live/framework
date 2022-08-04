# typed: strict

require_relative "update_context"
require_relative "vnode"

module Mayu
  module VDOM
    class CSSAttributes
      extend T::Sig

      # CSS properties which accept numbers but are not in units of "px".
      # Copied from React:
      # https://github.com/facebook/react/blob/a7c57268fb71163e4abb5e386c0d0e63290baaae/packages/react-dom/src/shared/CSSProperty.js
      UNITLESS_PROPERTIES =
        T.let(
          [
            :animation_iteration_count,
            :aspect_ratio,
            :border_image_outset,
            :border_image_slice,
            :border_image_width,
            :box_flex,
            :box_flex_group,
            :box_ordinal_group,
            :column_count,
            :columns,
            :flex,
            :flex_grow,
            :flex_positive,
            :flex_shrink,
            :flex_negative,
            :flex_order,
            :grid_area,
            :grid_row,
            :grid_row_end,
            :grid_row_span,
            :grid_row_start,
            :grid_column,
            :grid_column_end,
            :grid_column_span,
            :grid_column_start,
            :font_weight,
            :line_clamp,
            :line_height,
            :opacity,
            :order,
            :orphans,
            :tab_size,
            :widows,
            :z_index,
            :zoom,
            # SVG-related properties
            :fill_opacity,
            :flood_opacity,
            :stop_opacity,
            :stroke_dasharray,
            :stroke_dashoffset,
            :stroke_miterlimit,
            :stroke_opacity,
            :stroke_width
          ].freeze,
          T::Array[Symbol]
        )

      sig { returns(T::Hash[Symbol, T.untyped]) }
      attr_reader :properties

      sig { params(properties: T.untyped).void }
      def initialize(**properties)
        @properties = properties
      end

      sig { returns(String) }
      def to_s
        @properties
          .map do |property, value|
            format(
              "%s:%s;",
              transform_property(property),
              transform_value(property, value)
            )
          end
          .join
      end

      sig do
        params(ctx: UpdateContext, vnode: VNode, other: CSSAttributes).void
      end
      def patch(ctx, vnode, other)
        (properties.keys | other.properties.keys).sort.each do |property|
          old_value = properties[property]
          new_value = other.properties[property]

          next if old_value == new_value

          unless new_value
            ctx.css(vnode, transform_property(property))
            next
          end

          ctx.css(
            vnode,
            transform_property(property),
            transform_value(property, new_value)
          )
        end
      end

      private

      sig { params(property: Symbol).returns(String) }
      def transform_property(property)
        property.to_s.tr("_", "-")
      end

      sig { params(property: Symbol, value: T.untyped).returns(String) }
      def transform_value(property, value)
        if value.is_a?(Numeric) && !UNITLESS_PROPERTIES.include?(property)
          "#{value}px"
        else
          value.to_s
        end
      end
    end
  end
end
