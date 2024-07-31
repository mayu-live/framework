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
            puts "\e[1;91mNo stylesheet defined\e[0;31m (#{@component.module_path})\e[0m"
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
                end
              end
            end
            .flatten
            .compact
            .uniq

        unless @warned
          unless missing.empty?
            available_class_names =
              @classes.keys.reject { _1.start_with?("__") }.join(", ")

            Console.logger.error(
              @style_sheets.map(&:source_filename).join(", "),
              format(<<~MSG, missing.join(" "), available_class_names)
              Could not find classes: \e[1;31m.%s\e[0m
              Available class names:
              \e[1;33m%s\e[0m
              MSG
            )
          end

          @warned = true
        end

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
    end
  end
end
