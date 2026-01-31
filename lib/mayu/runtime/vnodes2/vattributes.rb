# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "securerandom"
require "cgi"

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
              in [[:rest, :args]]
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

            if key == :class
              updated_attributes[key] = update_class(
                patcher,
                key,
                old_value,
                new_value
              )
              next
            end

            if key == :style
              updated_attributes[key] = update_style(
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

        def write_html(out)
          attributes = render_for_html
          internal =
            Mayu::Runtime::DOM::INJECT_MAYU_ID ? { mayu_id: @parent.id } : {}

          (internal.merge(attributes))
            .except(:slot)
            .each do |attr, value|
              next if value.nil?

              if attr == :style && value.is_a?(Hash)
                value = InlineStyle.stringify(value)
              end

              value = value.join(" ") if attr == :class && value.is_a?(Array)

              rendered_value =
                if value.respond_to?(:to_js)
                  value.to_js
                else
                  CGI.escape_html(value.to_s)
                end

              name = CGI.escape_html(attr.to_s.tr("_", "-"))
              out << format(' %s="%s"', name, rendered_value)
            end
        end

        def render_for_html
          attrs = normalize_attributes(flatten_props(@descriptor.props || {}))

          attrs
            .transform_values do |value|
              case value
              when Listener
                value.to_js
              else
                value
              end
            end
            .tap do |hash|
              hash.each do |key, value|
                next unless key.to_s.start_with?("on")
                next if value.is_a?(String)
                next unless value

                listener = Listener[value]
                @engine.add_listener(listener)
                hash[key] = listener.to_js
                @attributes[key] = listener
              end
            end
        end

        def rehydrate_listeners(component_map)
          @attributes.each_value do |value|
            next unless value.is_a?(Listener)
            value.rehydrate(component_map)
            @engine.add_listener(value) if value.callback
          end
        end

        private

        def normalize_attributes(attrs)
          attrs.each_with_object({}) do |(key, value), obj|
            if key.to_s.start_with?("on")
              obj[key] = (value == false ? nil : value)
            elsif key == :style
              obj[key] = value
            elsif key == :class
              obj[key] = Array(value).flatten.compact
            else
              obj[key] = normalize_attribute_value(key, value)
            end
          end
        end

        def normalize_attribute_value(key, value)
          return if value.nil?
          return if value == false

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
            return old_value if old_value.callback&.same?(new_value)
            @engine.remove_listener(old_value)
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

          listener = @engine.add_listener(Listener[new_value])
          patcher << Patches::SetAttribute[@parent.dom_id, key, listener.to_js]
          listener
        end

        def update_class(patcher, key, old_value, new_value)
          old_classes = Array(old_value).flatten.compact
          new_classes = Array(new_value).flatten.compact

          if new_classes.empty?
            unless old_classes.empty?
              patcher << Patches::RemoveAttribute[@parent.dom_id, key]
            end
            return nil
          end

          added = new_classes - old_classes
          removed = old_classes - new_classes

          unless added.empty?
            patcher << Patches::AddClass[@parent.dom_id, added]
          end
          unless removed.empty?
            patcher << Patches::RemoveClass[@parent.dom_id, removed]
          end

          new_classes
        end

        def update_style(patcher, key, old_value, new_value)
          old_styles = old_value.is_a?(Hash) ? old_value : {}
          new_styles = new_value.is_a?(Hash) ? new_value : {}

          if new_styles.empty?
            unless old_styles.empty?
              patcher << Patches::RemoveAttribute[@parent.dom_id, key]
            end
            return nil
          end
          InlineStyle.diff(@parent.dom_id, old_styles, new_styles) do |patch|
            patcher << patch
          end

          new_styles
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
