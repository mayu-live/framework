# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module Marshalling
      ComponentRef = Data.define(:filename, :class_name, :klass)

      def self.dump_value(value)
        case value
        in Hash
          value.transform_values { dump_value(_1) }
        in Array
          value.map { dump_value(_1) }
        in Proc | Async::Task
          nil
        in Class
          dump_component_class(value)
        else
          value
        end
      end

      def self.load_value(value, fallback_class: nil)
        case value
        in Hash
          value.transform_values { load_value(_1) }
        in Array
          value.map { load_value(_1) }
        in ComponentRef
          resolve_component_ref(value, fallback_class:)
        else
          value
        end
      end

      def self.dump_component_class(value)
        return value unless component_class?(value)

        module_path = value.module_path if value.respond_to?(:module_path)
        class_name = value.name&.split("::")&.last

        if module_path.nil? || module_path.empty? ||
             module_path.start_with?("(internal)::")
          ComponentRef.new(nil, class_name, value)
        else
          ComponentRef.new(module_path, class_name, nil)
        end
      end

      def self.resolve_component_ref(ref, fallback_class: nil)
        return ref unless ref.is_a?(ComponentRef)

        return ref.klass if ref.klass.is_a?(Class)
        return fallback_class if fallback_class.is_a?(Class)

        module_path = ref.filename
        class_name = ref.class_name

        if module_path.nil? || module_path.empty?
          raise "Missing component module path for #{ref.inspect}"
        end

        system = Modules::System.current
        mod = system&.get_mod(module_path)

        default_export =
          if system&.respond_to?(:import)
            begin
              system.import(module_path, "/")
            rescue StandardError
              nil
            end
          elsif mod&.const_defined?(:Exports)
            exports = mod.const_get(:Exports)
            exports.const_get(:Default) if exports.const_defined?(:Default)
          end

        mod ||= system&.get_mod(module_path)
        raise "Could not resolve module #{module_path.inspect}" unless mod

        exports = mod.const_get(:Exports)
        const_name = class_name.to_s.split("::").last
        return default_export if const_name.empty?
        if exports.const_defined?(const_name)
          return exports.const_get(const_name)
        end
        return default_export if default_export

        raise(
          "Could not resolve component class #{const_name.inspect} in #{module_path.inspect}"
        )
      end

      def self.component_class?(value)
        value.is_a?(Class) && value <= Mayu::Component::Base
      end
    end
  end
end
