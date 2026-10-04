# frozen_string_literal: true

module Mayu
  module Klenod
    class ComponentResolver
      def initialize(provider)
        @provider = provider
      end

      def dump_component_class(component_class)
        module_id, class_name = @provider.class_reference(component_class) if @provider.respond_to?(:class_reference)
        module_id ||= module_id_from_path(component_class)
        return unless module_id

        class_name ||= component_class.name&.split("::")&.last
        Runtime::Marshalling::ComponentRef.new(module_id.to_s, class_name, nil, module_digest(module_id))
      rescue KeyError
        nil
      end

      def resolve_component_ref(reference)
        # A transferred session can resume against a fresh development
        # provider, whose graph has not evaluated this component yet. `entry`
        # loads it before exposing the exports module.
        exports =
          if @provider.respond_to?(:entry)
            @provider.exports(@provider.entry(reference.filename))
          else
            @provider.exports(reference.filename)
          end
        class_name = reference.class_name.to_s

        if exports.const_defined?(class_name, false)
          return exports.const_get(class_name, false)
        end

        # A component renamed within its module is still its default export.
        short_name = class_name.split("::").last
        if exports.const_defined?(short_name, false)
          return exports.const_get(short_name)
        end
        if exports.const_defined?(:Default, false)
          exports.const_get(:Default)
        end
      end

      # `[module_id, constant_path]` for a class defined in an app module.
      def class_reference(klass)
        @provider.class_reference(klass) if @provider.respond_to?(:class_reference)
      end

      def resolve_class(module_id, constant_path)
        @provider.resolve_class(module_id, constant_path)
      end

      # Nil when the module is gone, which a restore treats as changed.
      def module_digest(module_id)
        @provider.module_digest(module_id.to_s) if @provider.respond_to?(:module_digest)
      rescue
        nil
      end

      private

      def module_id_from_path(component_class)
        return unless component_class.respond_to?(:module_path)

        module_path = component_class.module_path
        return if module_path.nil? || module_path.empty? || module_path.start_with?("(internal)::")

        @provider.module_id_for(module_path)
      end
    end
  end
end
