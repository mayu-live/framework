# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Component
    module CSSUnits
      CustomProperty =
        Data.define(:name) do
          def self.[](name) = new(name.to_s.tr("_", "-"))

          def to_s = "var(#{name})"
          alias inspect to_s
        end

      Calc =
        Data.define(:left, :operator, :right) do
          def to_s = "calc(#{left} #{operator} #{right})".gsub("(calc(", "((")
          alias inspect to_s

          def +(other) = Calc[self, __method__, other]
          def -(other) = Calc[self, __method__, other]
          def *(other) = Calc[self, __method__, other]
          def /(other) = Calc[self, __method__, other]
        end

      NumberWithUnit =
        Data.define(:number, :unit) do
          def to_s = "#{number}#{unit}"
          alias inspect to_s

          def +(other) = handle_operator(__method__, other)
          def -(other) = handle_operator(__method__, other)
          def *(other) = handle_operator(__method__, other)
          def /(other) = handle_operator(__method__, other)

          private

          def handle_operator(operator, other)
            case other
            when Symbol
              Calc[self, operator, CustomProperty[other]]
            when Calc
              Calc[self, operator, other]
            when NumberWithUnit
              if unit == other.unit
                NumberWithUnit[number.send(operator, other.number), unit]
              else
                Calc[self, operator, other]
              end
            else
              NumberWithUnit[number.send(operator, other), unit]
            end
          end
        end

      module Refinements
        refine Numeric do
          def with_css_unit(unit) = NumberWithUnit[self, unit]

          def percent = with_css_unit(:%)
          def cm = with_css_unit(__method__)
          def mm = with_css_unit(__method__)
          def Q = with_css_unit(:q)
          def in = with_css_unit(__method__)
          def pc = with_css_unit(__method__)
          def pt = with_css_unit(__method__)
          def px = with_css_unit(__method__)

          # Font size of the parent, in the case of typographical properties like
          # font-size, and font size of the element itself, in the case of other
          # properties like width.
          def em = with_css_unit(__method__)
          # x-height of the element's font.
          def ex = with_css_unit(__method__)
          # The advance measure (width) of the glyph "0" of the element's font.
          def ch = with_css_unit(__method__)
          # Font size of the root element.
          def rem = with_css_unit(__method__)
          # Line height of the element.
          def lh = with_css_unit(__method__)
          # Line height of the root element. When used on the font-size or
          # line-height properties of the root element, it refers to the
          # properties' initial value.
          def rlh = with_css_unit(__method__)
          # 1% of the viewport's width.
          def vw = with_css_unit(__method__)
          # 1% of the viewport's height.
          def vh = with_css_unit(__method__)
          # 1% of the viewport's smaller dimension.
          def vmin = with_css_unit(__method__)
          # 1% of the viewport's larger dimension.
          def vmax = with_css_unit(__method__)
          # 1% of the size of the initial containing block in the direction of
          # the root element's block axis.
          def vb = with_css_unit(__method__)
          # 1% of the size of the initial containing block in the direction of
          # the root element's inline axis.
          def vi = with_css_unit(__method__)
          # 1% of the small viewport's width and height, respectively.
          def svw = with_css_unit(__method__)
          def svh = with_css_unit(__method__)
          # 1% of the large viewport's width and height, respectively.
          def lvw = with_css_unit(__method__)
          def lvh = with_css_unit(__method__)
          # 1% of the dynamic viewport's width and height, respectively.
          def dvw = with_css_unit(__method__)
          def dvh = with_css_unit(__method__)

          # 1% of a query container's width
          def cqw = with_css_unit(__method__)
          # 1% of a query container's height
          def cqh = with_css_unit(__method__)
          # 1% of a query container's inline size
          def cqi = with_css_unit(__method__)
          # 1% of a query container's block size
          def cqb = with_css_unit(__method__)
          # The smaller value of either cqi or cqb
          def cqmin = with_css_unit(__method__)
          # The larger value of either cqi or cqb
          def cqmax = with_css_unit(__method__)

          # Fraction of grid
          def fr = with_css_unit(__method__)
        end
      end
    end
  end
end
