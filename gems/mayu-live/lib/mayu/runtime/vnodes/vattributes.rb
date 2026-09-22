# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "securerandom"
require "cgi"
require "did_you_mean"

require_relative "base"
require_relative "../inline_style"
require_relative "../commands"

module Mayu
  module Runtime
    module VNodes
      class VAttributes < Base
        EMPTY_CLASS_NAMES = [].freeze
        EMPTY_STYLES = {}.freeze

        class NoCallbackMethodError < ArgumentError
          def initialize(callback, component, suggestions)
            component_name =
              component.class.respond_to?(:module_path) &&
              component.class.module_path
            component_name = component.class.name if component_name.nil? || component_name.empty?

            message =
              "Callback method #{callback.method_name.inspect} is not defined on #{component_name}"
            message += "\n\nDid you mean?  #{suggestions.join("\n               ")}" unless suggestions.empty?
            super(message)

            if callback.source_location
              path, line = callback.source_location
              set_backtrace(["#{path}:#{line}:in 'render'"])
            end
          end
        end

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
          rescue NameError
            component = callback.component
            raise NoCallbackMethodError.new(
              callback,
              component,
              callback_suggestions(component, callback.method_name)
            )
          end

          private def callback_suggestions(component, method_name)
            methods = component.class.public_instance_methods(false)
            name = method_name.to_s
            prefixed = methods.select { it.to_s.delete_prefix("handle_") == name }
            corrected = DidYouMean::SpellChecker.new(dictionary: methods).correct(name)
            (prefixed + corrected).map(&:to_s).uniq.first(3)
          end

          def marshal_dump
            component_id =
              callback.component.instance_variable_get(:@__vnode_id)
            [id, component_id, callback.method_name, callback.source_location]
          end

          def marshal_load(a)
            @id, @component_id, @method_name, @source_location = a
            @callback = nil
          end

          def rehydrate(component_map)
            component = component_map[@component_id]
            return unless component
            @callback =
              Descriptors::Callback[component, @method_name, @source_location]
          end

          def rebind_component(vnode_id, component)
            return unless callback
            current_id =
              callback.component.instance_variable_get(:@__vnode_id)
            return unless current_id == vnode_id

            @callback =
              Descriptors::Callback[
                component,
                callback.method_name,
                callback.source_location
              ]
          end
        end

        def initialize(descriptor, parent:, engine:)
          super
          @attributes = normalize_attributes(flatten_props(@descriptor.props))
          normalize_listeners!(@attributes)
        end

        def update(collector, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
          listeners_changed = false

          new_attributes =
            normalize_attributes(flatten_props(@descriptor.props))
          return if @attributes.empty? && new_attributes.empty?

          updated_attributes = @attributes.dup

          (@attributes.keys | new_attributes.keys).each do |key|
            old_value = @attributes[key]
            new_value = new_attributes[key]

            case key
            when :class
              value = update_class(collector, key, old_value, new_value)
              if value.nil?
                updated_attributes.delete(key)
              elsif !value.equal?(old_value)
                updated_attributes[key] = value
              end
            when :style
              value = update_style(collector, key, old_value, new_value)
              if value.nil?
                updated_attributes.delete(key)
              elsif !value.equal?(old_value)
                updated_attributes[key] = value
              end
            else
              if key.start_with?("on")
                value = update_callback(collector, key, old_value, new_value)
                listeners_changed ||= !value.equal?(old_value)
                if value.nil?
                  updated_attributes.delete(key)
                elsif !value.equal?(old_value)
                  updated_attributes[key] = value
                end
              elsif new_value.nil?
                if old_value
                  collector << Commands::RemoveAttribute[@parent.dom_id, key]
                end
                updated_attributes.delete(key)
              elsif old_value != new_value
                collector << Commands::SetAttribute[
                  @parent.dom_id,
                  key,
                  new_value.to_s
                ]
                updated_attributes[key] = new_value
              end
            end
          end

          @attributes = updated_attributes
          @parent.mark_listeners_dirty if listeners_changed
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

              next if attr == :style && value == ""

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
            event_name = name.to_s.sub(/\Aon[-_]?/, "").downcase
            yield event_name, listener if
              listener.is_a?(Listener)
          end
        end

        def rehydrate_listeners(component_map)
          @attributes.each_value do |value|
            next unless value.is_a?(Listener)
            value.rehydrate(component_map)
          end
        end

        private

        def normalize_listeners!(attrs)
          attrs.each do |key, value|
            next unless key.start_with?("on")
            next if value.nil?

            if value.is_a?(Listener)
              next
            end

            if value.is_a?(String)
              raise ArgumentError,
                "Raw string event handler #{key.inspect} is not supported; use H.callback"
            end

            listener = Listener[value].validate!
            attrs[key] = listener
          end
        end

        def normalize_attributes(attrs)
          attrs.each_with_object({}) do |(key, value), obj|
            obj[key] = if key == :style
              if value.is_a?(Hash)
                InlineStyle.compact(value)
              else
                ((value == false) ? nil : value)
              end
            elsif key == :class
              normalize_class_names(value)
            elsif key.start_with?("on")
              ((value == false) ? nil : value)
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
            collector << Commands::RemoveListener[
              @parent.dom_id,
              key.to_s.sub(/\Aon[-_]?/, "").downcase,
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

          listener = Listener[new_value].validate!
          collector << Commands::SetListener[
            @parent.dom_id,
            key.to_s.sub(/\Aon[-_]?/, "").downcase,
            listener.id
          ]
          listener
        end

        def update_class(collector, key, old_value, new_value)
          old_classes = old_value || EMPTY_CLASS_NAMES
          new_classes = new_value || EMPTY_CLASS_NAMES

          if new_classes.empty?
            unless old_classes.empty?
              collector << Commands::RemoveAttribute[@parent.dom_id, key]
            end
            return nil
          end

          return old_classes if old_classes == new_classes

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

        def normalize_class_names(value, class_names = [])
          case value
          when nil, false
            nil
          when Array
            value.each { |item| normalize_class_names(item, class_names) }
          else
            class_names.concat(value.to_s.split)
          end

          class_names
        end

        def update_style(collector, key, old_value, new_value)
          old_styles = old_value.is_a?(Hash) ? old_value : EMPTY_STYLES
          new_styles = new_value.is_a?(Hash) ? new_value : EMPTY_STYLES

          if new_styles.empty?
            unless old_styles.empty?
              collector << Commands::RemoveAttribute[@parent.dom_id, key]
            end
            return nil
          end
          return old_styles if old_styles == new_styles

          InlineStyle.diff(@parent.dom_id, old_styles, new_styles) do |command|
            collector << command
          end

          new_styles
        end

        def flatten_props(hash)
          flatten_props_into(hash, {}, nil)
        end

        def flatten_props_into(hash, attributes, prefix)
          hash.each do |key, value|
            if prefix.nil? && key == :style
              attributes[key] = value
              next
            end

            if value.is_a?(Hash)
              child_prefix = prefix ? "#{prefix}-#{key}" : key.to_s
              flatten_props_into(value, attributes, child_prefix)
            else
              name =
                if prefix
                  :"#{prefix}-#{key}"
                elsif key.is_a?(Symbol)
                  key
                else
                  key.to_s.to_sym
                end
              attributes[name] = value
            end
          end

          attributes
        end
      end
    end
  end
end
