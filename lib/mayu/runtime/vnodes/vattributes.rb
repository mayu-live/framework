# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "../inline_style"

module Mayu
  module Runtime
    module VNodes
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
          end

        def initialize(...)
          super
          @attributes = {}
          @attributes = update_attributes(@descriptor.props)
        ensure
          @initialized = true
        end

        def marshal_dump
          [super, @attributes, @initialized]
        end

        def marshal_load(a)
          a => [a, attributes, initialized]
          super(a)
          @attributes = attributes
          @initialized = initialized
        end

        def update(descriptor)
          @descriptor = descriptor
          @attributes = update_attributes(flatten_props(@descriptor.props))
        end

        def render
          @attributes
        end

        private

        def patch(...)
          super if @initialized
        end

        def update_attributes(props)
          @attributes
            .keys
            .union(props.keys)
            .map do |prop|
              old = @attributes[prop]
              new = props[prop] || nil

              if prop == :style
                update_style(prop, old, new)
              elsif prop.start_with?("on")
                update_callback(prop, old, new)
              else
                update_attribute(prop, old, new)
              end
            end
            .compact
            .to_h
        end

        def update_style(prop, old, new)
          unless new
            patch(Patches::RemoveAttribute[@parent.id, :style])
            return
          end

          InlineStyle.diff(@parent.id, old || {}, new) { patch(_1) }

          [prop, new]
        end

        def update_callback(prop, old, new)
          if old
            if old.is_a?(Listener)
              return prop, old if old.callback.same?(new)

              closest(VDocument).remove_listener(old)
            elsif old.is_a?(String)
              return prop, old if old == new
            end

            unless new
              patch(Patches::RemoveAttribute[@parent.id, prop])
              return
            end
          end

          return unless new

          if new.is_a?(String)
            patch(Patches::SetAttribute[@parent.id, prop, new])
            [prop, new]
          else
            listener = closest(VDocument).add_listener(Listener[new])
            patch(Patches::SetAttribute[@parent.id, prop, listener.to_js])
            [prop, listener]
          end
        end

        def update_attribute(prop, old, new)
          unless new
            patch(Patches::RemoveAttribute[@parent.id, prop])
            return
          end

          return prop, new.to_s if old.to_s == new.to_s

          if prop == :class
            patch(Patches::SetClassName[@parent.id, new.to_s])
          else
            patch(Patches::SetAttribute[@parent.id, prop, new.to_s])
          end

          [prop, new.to_s]
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
                { current_path.join("-") => v }
              end
            )
          end
        end
      end
    end
  end
end
