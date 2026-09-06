# frozen_string_literal: true

module Mayu
  module Klenod
    class ComponentResolver
      def initialize(provider)
        @provider = provider
      end

      def dump_component_class(component_class)
        module_path =
          component_class.module_path if component_class.respond_to?(
          :module_path
        )
        if module_path.nil? || module_path.empty? ||
             module_path.start_with?("(internal)::")
          return
        end

        module_id = @provider.module_id_for(module_path)
        class_name = component_class.name&.split("::")&.last
        Runtime::Marshalling::ComponentRef.new(module_id.to_s, class_name, nil)
      rescue KeyError
        nil
      end

      def resolve_component_ref(reference)
        exports = @provider.exports(reference.filename)
        class_name = reference.class_name.to_s.split("::").last

        if exports.const_defined?(class_name, false)
          return exports.const_get(class_name)
        end
        if exports.const_defined?(:Default, false)
          return exports.const_get(:Default)
        end
      end
    end
  end
end
