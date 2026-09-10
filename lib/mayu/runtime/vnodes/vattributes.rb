# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "securerandom"
require "cgi"

require_relative "base"
require_relative "../inline_style"
require_relative "../commands"

module Mayu
  module Runtime
    module VNodes
      class VAttributes < Base
        class Listener
          def self.[](callback) = new(SecureRandom.alphanumeric(32), callback)

          def initialize(id, callback)
            @id = id
            @callback = callback
          end

          attr_reader :id
          attr_reader :callback

          def call(payload)
            method = callback.component.method(callback.method_name)
            parameters = method.parameters

            if parameters.empty?
              method.call
            elsif parameters.length == 1 &&
                %i[req opt rest].include?(parameters.first.first)
              method.call(payload)
            elsif parameters.any? { |type, _| type == :keyrest } &&
                parameters.all? do |type, _|
                  %i[key keyreq keyrest].include?(type)
                end
              method.call(**payload)
            else
              raise ArgumentError,
                "Callback #{callback.method_name} must accept no arguments, one positional event argument, or keyword rest arguments"
            end
          end

          def validate!
            parameters = callback.component.method(callback.method_name).parameters
            positional =
              parameters.length == 1 &&
              %i[req opt rest].include?(parameters.first.first)
            keyword_rest =
              parameters.any? { |type, _| type == :keyrest } &&
              parameters.all? do |type, _|
                %i[key keyreq keyrest].include?(type)
              end

            unless parameters.empty? || positional || keyword_rest
              raise ArgumentError,
                "Callback #{callback.method_name} must accept no arguments, one positional event argument, or keyword rest arguments"
            end

            self
          rescue NameError => error
            raise ArgumentError,
              "Callback method #{callback.method_name.inspect} is not defined on #{callback.component.class}",
              cause: error
          end

          def marshal_dump
            component_id =
              callback.component.instance_variable_get(:@__vnode_id)
            [id, component_id, callback.method_name]
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

          def rebind_component(vnode_id, component)
            return unless callback
            current_id =
              callback.component.instance_variable_get(:@__vnode_id)
            return unless current_id == vnode_id

            @callback =
              Descriptors::Callback[component, callback.method_name]
          end
        end

        def initialize(descriptor, parent:, engine:)
          super
          @attributes = normalize_attributes(flatten_props(@descriptor.props))
          register_listeners!(@attributes)
        end

        def update(collector, descriptor = nil)
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
                collector,
                key,
                old_value,
                new_value
              )
              next
            end

            if key == :class
              updated_attributes[key] = update_class(
                collector,
                key,
                old_value,
                new_value
              )
              next
            end

            if key == :style
              updated_attributes[key] = update_style(
                collector,
                key,
                old_value,
                new_value
              )
              next
            end

            if new_value.nil?
              if old_value
                collector << Commands::RemoveAttribute[@parent.dom_id, key]
              end
              updated_attributes[key] = nil
              next
            end

            next if old_value == new_value

            collector << Commands::SetAttribute[
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
            Mayu::Runtime::DOM::INJECT_MAYU_ID ? {mayu_id: @parent.id} : {}

          internal.merge(attributes)
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
          @attributes.transform_values do |value|
            value.is_a?(Listener) ? nil : value
          end
        end

        def each_listener
          @attributes.each do |name, listener|
            yield name.to_s.delete_prefix("on").downcase, listener if
              listener.is_a?(Listener)
          end
        end

        def remove_listeners
          @attributes.each_value do |listener|
            @engine.remove_listener(listener) if listener.is_a?(Listener)
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

        def register_listeners!(attrs)
          attrs.each do |key, value|
            next unless key.to_s.start_with?("on")
            next if value.nil?

            if value.is_a?(Listener)
              @engine.add_listener(value)
              next
            end

            if value.is_a?(String)
              raise ArgumentError,
                "Raw string event handler #{key.inspect} is not supported; use H.callback"
            end

            listener = Listener[value].validate!
            @engine.add_listener(listener)
            attrs[key] = listener
          end
        end

        def normalize_attributes(attrs)
          attrs.each_with_object({}) do |(key, value), obj|
            obj[key] = if key.to_s.start_with?("on")
              ((value == false) ? nil : value)
            elsif key == :style
              value
            elsif key == :class
              normalize_class_names(value)
            else
              normalize_attribute_value(key, value)
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

        def update_callback(collector, key, old_value, new_value)
          if old_value.is_a?(Listener)
            return old_value if old_value.callback&.same?(new_value)
            @engine.remove_listener(old_value)
            collector << Commands::RemoveListener[
              @parent.dom_id,
              key.to_s.delete_prefix("on").downcase,
              old_value.id
            ]
          end

          if new_value.nil?
            return nil
          end

          if new_value.is_a?(String)
            raise ArgumentError,
              "Raw string event handler #{key.inspect} is not supported; use H.callback"
          end

          listener = @engine.add_listener(Listener[new_value].validate!)
          collector << Commands::SetListener[
            @parent.dom_id,
            key.to_s.delete_prefix("on").downcase,
            listener.id
          ]
          listener
        end

        def update_class(collector, key, old_value, new_value)
          old_classes = normalize_class_names(old_value)
          new_classes = normalize_class_names(new_value)

          if new_classes.empty?
            unless old_classes.empty?
              collector << Commands::RemoveAttribute[@parent.dom_id, key]
            end
            return nil
          end

          added = new_classes - old_classes
          removed = old_classes - new_classes

          unless added.empty?
            collector << Commands::AddClass[@parent.dom_id, added]
          end
          unless removed.empty?
            collector << Commands::RemoveClass[@parent.dom_id, removed]
          end

          new_classes
        end

        def normalize_class_names(value)
          Array(value).flatten.compact.flat_map { it.to_s.split }
        end

        def update_style(collector, key, old_value, new_value)
          old_styles = old_value.is_a?(Hash) ? old_value : {}
          new_styles = new_value.is_a?(Hash) ? new_value : {}

          if new_styles.empty?
            unless old_styles.empty?
              collector << Commands::RemoveAttribute[@parent.dom_id, key]
            end
            return nil
          end
          InlineStyle.diff(@parent.dom_id, old_styles, new_styles) do |command|
            collector << command
          end

          new_styles
        end

        def flatten_props(hash, path = [])
          hash.reduce({}) do |obj, (k, v)|
            next {**obj, k => v} if k == :style && path.empty?

            current_path = [*path, k]

            obj.merge(
              case v
              when Hash
                flatten_props(v, current_path)
              else
                {current_path.join("-").to_sym => v}
              end
            )
          end
        end
      end
    end
  end
end
