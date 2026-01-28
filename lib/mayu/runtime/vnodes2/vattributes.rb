# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "securerandom"

require_relative "base"
require_relative "../inline_style"
require_relative "../patches"

module Mayu
  module Runtime
    module VNodes2
      class VAttributes < Base
        Listener =
          Data.define(:id, :callback) do
            def self.[](callback) = new(SecureRandom.alphanumeric(32), callback)

            def to_js = "Mayu.callback(event,'#{id}')"

            def call(payload)
              method = callback.component.method(callback.method_name)

              case method.parameters
              in []
                method.call
              in [[:req, Symbol]]
                method.call(payload)
              in [[:keyrest, Symbol]]
                method.call(**payload)
              end
            end

            def marshal_dump
              component_id =
                callback.component.instance_variable_get(:@__vnode_id)
              [@id, component_id, callback.method_name]
            end

            def marshal_load(a)
              @id, @component_id, @method_name = a
              @callback = nil
            end

            def rehydrate(component_map)
              component = component_map[@component_id]
              return unless component
              @callback = Descriptors::Callback[component, @method_name]
            end
          end

        def initialize(descriptor, parent:, engine:)
          super
          @attributes = normalize_attributes(flatten_props(@descriptor.props))
        end

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor

          new_attributes =
            normalize_attributes(flatten_props(@descriptor.props))
          updated_attributes = @attributes.dup

          (@attributes.keys | new_attributes.keys).each do |key|
            old_value = @attributes[key]
            new_value = new_attributes[key]

            if key.to_s.start_with?("on")
              updated_attributes[key] = update_callback(
                patcher,
                key,
                old_value,
                new_value
              )
              next
            end

            if new_value.nil?
              if old_value
                patcher << Patches::RemoveAttribute[@parent.dom_id, key]
              end
              updated_attributes[key] = nil
              next
            end

            next if old_value == new_value

            patcher << Patches::SetAttribute[
              @parent.dom_id,
              key,
              new_value.to_s
            ]

            updated_attributes[key] = new_value
          end

          @attributes = updated_attributes
        end

        def write_html(_out)
        end

        def rehydrate_listeners(document, component_map)
          @attributes.each_value do |value|
            next unless value.is_a?(Listener)
            value.rehydrate(component_map)
            document.add_listener(value) if value.callback
          end
        end

        private

        def normalize_attributes(attrs)
          attrs.each_with_object({}) do |(key, value), obj|
            if key.to_s.start_with?("on")
              obj[key] = value
            else
              obj[key] = normalize_attribute_value(key, value)
            end
          end
        end

        def normalize_attribute_value(key, value)
          return if value.nil?

          return if value == "" && key in :class | :style

          if key == :style && value.is_a?(Hash)
            return InlineStyle.stringify(value)
          end

          return value.join(" ") if key == :class && value.is_a?(Array)

          return value.to_js if value.respond_to?(:to_js)

          value.to_s
        end

        def marshal_dump
          [super, @attributes]
        end

        def marshal_load(a)
          a => [base, attributes]
          super(base)
          @attributes = attributes
        end

        def update_callback(patcher, key, old_value, new_value)
          if old_value.is_a?(Listener)
            return old_value if old_value.callback.same?(new_value)
            closest(VDocument)&.remove_listener(old_value)
          elsif old_value.is_a?(String)
            return old_value if old_value == new_value
          end

          if new_value.nil?
            patcher << Patches::RemoveAttribute[@parent.dom_id, key]
            return nil
          end

          if new_value.is_a?(String)
            patcher << Patches::SetAttribute[@parent.dom_id, key, new_value]
            return new_value
          end

          listener = closest(VDocument)&.add_listener(Listener[new_value])
          patcher << Patches::SetAttribute[@parent.dom_id, key, listener.to_js]
          listener
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
