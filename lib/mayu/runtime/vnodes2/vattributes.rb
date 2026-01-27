# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "../inline_style"
require_relative "../patches"

module Mayu
  module Runtime
    module VNodes2
      class VAttributes < Base
        def initialize(descriptor, parent:, engine:)
          super
          @attributes = normalize_attributes(flatten_props(@descriptor.props))
        end

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor

          new_attributes =
            normalize_attributes(flatten_props(@descriptor.props))

          (@attributes.keys | new_attributes.keys).each do |key|
            old_value = @attributes[key]
            new_value = new_attributes[key]

            if new_value.nil?
              if old_value
                patcher << Patches::RemoveAttribute[@parent.dom_id, key]
              end
              next
            end

            next if old_value == new_value

            patcher << Patches::SetAttribute[
              @parent.dom_id,
              key,
              new_value.to_s
            ]
          end

          @attributes = new_attributes
        end

        def write_html(_out)
        end

        private

        def normalize_attributes(attrs)
          attrs.each_with_object({}) do |(key, value), obj|
            obj[key] = normalize_attribute_value(key, value)
          end
        end

        def normalize_attribute_value(key, value)
          return if value.nil?

          return if key == :class && value.respond_to?(:empty?) && value.empty?

          return if key == :style && value.respond_to?(:empty?) && value.empty?

          if key == :style && value.is_a?(Hash)
            return InlineStyle.stringify(value)
          end

          return value.join(" ") if key == :class && value.is_a?(Array)

          return value.to_js if value.respond_to?(:to_js)

          value.to_s
        end

        def flatten_props(hash, path = [])
          hash.reduce({}) do |obj, (k, v)|
            next { **obj, k => v } if k == :style && path.empty?

            current_path = [*path, k]

            obj.merge(
              case v
              when Hash
                flatten_props(v, current_path)
              else
                { current_path.join("-").to_sym => v }
              end
            )
          end
        end
      end
    end
  end
end
