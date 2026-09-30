# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "../component/state"

module Mayu
  module Runtime
    # Prepares values for Marshal, so component state and props survive
    # session transfers and hot reloads.
    #
    # Hot reload evaluates a module again, so its constants name new classes
    # while existing state still holds instances of the old ones, and Marshal
    # refuses to write an object whose class name now means another class.
    # Instances of such replaced classes are written as an ObjectRef with their
    # class name and data instead, and rebuilt from the current class when
    # loaded. Replaced objects are found in hashes, arrays, component state and
    # each other, not inside other objects.
    module Marshalling
      ComponentRef = Data.define(:filename, :class_name, :klass)
      # Mutable, so it can be recorded before its payload is dumped, and
      # references between replaced objects keep pointing at each other.
      ObjectRef = Struct.new(:class_name, :kind, :payload)
      COMPONENT_RESOLVER_KEY = :mayu_component_resolver
      # Where Klenod evaluates app modules in development, the only place
      # classes are replaced.
      RELOADABLE_NAMESPACE = "Mayu::ModuleNamespace::"

      def self.with_component_resolver(resolver)
        previous = Fiber[COMPONENT_RESOLVER_KEY]
        Fiber[COMPONENT_RESOLVER_KEY] = resolver
        yield
      ensure
        Fiber[COMPONENT_RESOLVER_KEY] = previous
      end

      def self.dump_value(value)
        dump(value, {}.compare_by_identity)
      end

      def self.load_value(value, fallback_class: nil)
        load(value, {}.compare_by_identity, fallback_class:)
      end

      # `refs` maps each replaced object to its ObjectRef.
      def self.dump(value, refs)
        # Klenod evaluates module exports inside anonymous modules. Its SVG
        # imports are metadata objects from one of those modules, which Ruby
        # cannot marshal even though an element only needs their URL. Keep the
        # stable string representation in the persisted descriptor instead.
        return value.src if klenod_svg_metadata?(value)

        case value
        in Hash
          value.transform_values { dump(it, refs) }
        in Array
          value.map { dump(it, refs) }
        in Proc | Async::Task
          nil
        in Class
          dump_component_class(value)
        in Mayu::Component::State
          Mayu::Component::State.new(values: dump(value.marshal_dump, refs))
        else
          replaced_class?(value.class) ? dump_object(value, refs) : value
        end
      end

      # `objects` maps each ObjectRef to the object rebuilt from it.
      def self.load(value, objects, fallback_class: nil)
        case value
        in Hash
          value.transform_values { load(it, objects) }
        in Array
          value.map { load(it, objects) }
        in ComponentRef
          resolve_component_ref(value, fallback_class:)
        in ObjectRef
          load_object(value, objects)
        in Mayu::Component::State
          Mayu::Component::State.new(values: load(value.marshal_dump, objects))
        else
          value
        end
      end

      def self.replaced_class?(klass)
        name = klass.name
        return false unless name&.start_with?(RELOADABLE_NAMESPACE)

        !Object.const_get(name).equal?(klass)
      rescue NameError
        # The class is gone. Marshal reports it, as it would without this.
        false
      end

      def self.dump_object(value, refs)
        return refs[value] if refs.key?(value)

        ref = refs[value] = ObjectRef.new(value.class.name)
        ref.kind, payload =
          case value
          in Data
            [:data, value.to_h]
          in Struct
            [:struct, value.to_h]
          else
            if value.respond_to?(:marshal_dump)
              [:custom, value.marshal_dump]
            else
              ivars = value.instance_variables.to_h { [it, value.instance_variable_get(it)] }
              [:ivars, ivars]
            end
          end
        ref.payload = dump(payload, refs)
        ref
      end

      def self.load_object(ref, objects)
        return objects[ref] if objects.key?(ref)

        klass = Object.const_get(ref.class_name)

        case ref.kind
        in :data
          objects[ref] = klass.new(**load(ref.payload, objects))
        in :struct
          values = load(ref.payload, objects)
          objects[ref] = klass.new(*klass.members.map { values[it] })
        in :custom
          object = objects[ref] = klass.allocate
          object.marshal_load(load(ref.payload, objects))
          object
        in :ivars
          object = objects[ref] = klass.allocate
          load(ref.payload, objects).each { object.instance_variable_set(_1, _2) }
          object
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
