# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../style_sheet"
require_relative "../runtime/h"
require_relative "css_units"
require_relative "fetch"

module Mayu
  module Component
    class StyleSheets
      def initialize(component, style_sheets)
        @component = component
        @style_sheets = style_sheets
        @classes = merge_classes(style_sheets.map(&:classes))
      end

      def each(&)
        @style_sheets.each(&)
      end

      def [](*class_names)
        if @style_sheets.empty?
          unless class_names.compact.all? {
                   _1.start_with?("__") || String === _1
                 }
            Console.logger.error(@component, "No stylesheet defined")
          end

          return []
        end

        missing = []

        result =
          class_names
            .map do |class_name|
              case class_name
              in String
                class_name
              in Hash
                self[*class_name.filter { _2 }.keys]
              in Symbol
                @classes.fetch(class_name) do
                  missing << class_name unless class_name.start_with?("__")
                  nil
                end
              end
            end
            .flatten
            .compact
            .uniq

        warn_missing(missing)

        result
      end

      private

      def merge_classes(hashes)
        result = {}

        hashes.each do |hash|
          hash.each do |key, value|
            result[key] ||= []
            result[key] << value
          end
        end

        result
      end

      def warn_missing(missing)
        return if @warned || missing.empty?

        available = @classes.keys.reject { _1.start_with?("__") }

        Console.logger.error(
          @component,
          format(<<~MSG, join_class_names(missing), join_class_names(available))
              Could not find classes: \e[1;31m%s\e[0m
              Available class names:
              \e[1;33m%s\e[0m
              MSG
        )

        @warned = true
      end

      def join_class_names(class_names)
        class_names.map { ".#{_1}" }.join(", ")
      end
    end
  end
end
