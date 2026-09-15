# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module Marshalling
      ComponentRef = Data.define(:filename, :class_name, :klass)
      COMPONENT_RESOLVER_KEY = :mayu_component_resolver

      def self.with_component_resolver(resolver)
        previous = Fiber[COMPONENT_RESOLVER_KEY]
        Fiber[COMPONENT_RESOLVER_KEY] = resolver
        yield
      ensure
        Fiber[COMPONENT_RESOLVER_KEY] = previous
      end

      def self.dump_value(value)
        # Klenod evaluates module exports inside anonymous modules. Its SVG
        # imports are metadata objects from one of those modules, which Ruby
        # cannot marshal even though an element only needs their URL. Keep the
        # stable string representation in the persisted descriptor instead.
        return value.src if klenod_svg_metadata?(value)

        case value
        in Hash
          value.transform_values { dump_value(it) }
        in Array
          value.map { dump_value(it) }
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
          value.transform_values { load_value(it) }
        in Array
          value.map { load_value(it) }
        in ComponentRef
          resolve_component_ref(value, fallback_class:)
        else
          value
        end
      end

      def self.dump_component_class(value)
        return value unless component_class?(value)

        if (resolver = Fiber[COMPONENT_RESOLVER_KEY])
          reference = resolver.dump_component_class(value)
          return reference if reference
        end

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

        if (resolver = Fiber[COMPONENT_RESOLVER_KEY])
          component_class = resolver.resolve_component_ref(ref)
          return component_class if component_class
        end

        raise "Could not resolve component reference #{ref.inspect}"
      end

      def self.component_class?(value)
        value.is_a?(Class) && value <= Mayu::Component::Base
      end

      def self.klenod_svg_metadata?(value)
        value.respond_to?(:src) && value.class.name&.end_with?("::SvgMetadata")
      end
    end
  end
end
