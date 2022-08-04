# typed: strict

require "bundler"
require "pry"
require "sorbet-runtime"

class CSSAttributes
  class PatchSet
    extend T::Sig

    SET = :s
    REMOVE = :x

    Patch = T.type_alias { T::Array[T.untyped] }

    sig {returns(T::Array[Patch])}
    attr_reader :patches

    sig {void}
    def initialize
      @patches = T.let([], T::Array[Patch])
    end

    sig {params(property: String, value: String).void}
    def set(property, value)
      @patches.push([SET, property, value])
    end

    sig {params(property: String).void}
    def remove(property)
      @patches.push([REMOVE, property])
    end
  end

  extend T::Sig

  # CSS properties which accept numbers but are not in units of "px".
  # Copied from React:
  # https://github.com/facebook/react/blob/a7c57268fb71163e4abb5e386c0d0e63290baaae/packages/react-dom/src/shared/CSSProperty.js
  UNITLESS_PROPERTIES = T.let([
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
    :stroke_width,
  ].freeze, T::Array[Symbol])

  sig {returns(T::Hash[Symbol, T.untyped])}
  attr_reader :properties

  sig {params(properties: T.untyped).void}
  def initialize(**properties)
    @properties = properties
  end

  sig {returns(String)}
  def to_s
    @properties.map { |property, value|
      format("%s:%s;", transform_property(property), transform_value(property, value))
    }.join
  end

  sig {params(other: CSSAttributes).returns(PatchSet)}
  def diff(other)
    patch_set = PatchSet.new

    (properties.keys | other.properties.keys).sort.each do |property|
      old_value = properties[property]
      new_value = other.properties[property]

      if old_value == new_value
        # Nothing changed
        next
      end

      unless new_value
        patch_set.remove(transform_property(property))
        next
      end

      patch_set.set(
        transform_property(property),
        transform_value(property, new_value),
      )
    end

    patch_set
  end

  private

  sig {params(property: Symbol).returns(String)}
  def transform_property(property)
    property.to_s.tr("_", "-")
  end

  sig {params(property: Symbol, value: T.untyped).returns(String)}
  def transform_value(property, value)
    if value.is_a?(Numeric) && !UNITLESS_PROPERTIES.include?(property)
      "#{value}px"
    else
      value.to_s
    end
  end
end

attrs1 = CSSAttributes.new(
  width: 32,
  height: 54,
)

attrs2 = CSSAttributes.new(
  width: 64,
)

p attrs1.diff(attrs2).patches
