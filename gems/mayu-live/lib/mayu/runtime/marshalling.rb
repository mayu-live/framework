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
    # Classes defined in app modules can not be written by their Ruby name:
    # production evaluates modules in an anonymous namespace, and hot reload
    # replaces classes while state still holds instances of the old ones. With
    # a resolver (see with_component_resolver), their instances are written as
    # an ObjectRef: a ClassRef naming the module and the constant path inside
    # it, plus the object's data. Loading rebuilds them from whatever class
    # that reference names now. Such objects are found in hashes, arrays,
    # component state and each other, not inside other objects.
    module Marshalling
      ComponentRef =
        Data.define(:filename, :class_name, :klass, :digest) do
          def initialize(filename:, class_name:, klass:, digest: nil)
            super
          end
        end
      # A class defined in an app module, with the digest of that module's
      # code when the reference was written.
      ClassRef = Data.define(:module_id, :constant_path, :digest)
      # Mutable, so it can be recorded before its payload is dumped, and
      # objects that refer to each other keep doing so.
      ObjectRef = Struct.new(:class_ref, :kind, :payload)
      COMPONENT_RESOLVER_KEY = :mayu_component_resolver

      # The state of one dump: an ObjectRef per object, a ClassRef (or nil)
      # per class, and the digest of every module the value refers to.
      Dump = Struct.new(:refs, :class_refs, :dependencies)

      def self.with_component_resolver(resolver)
        previous = Fiber[COMPONENT_RESOLVER_KEY]
        Fiber[COMPONENT_RESOLVER_KEY] = resolver
        yield
      ensure
        Fiber[COMPONENT_RESOLVER_KEY] = previous
      end

      # Pass a hash as `dependencies` to collect `module_id => digest` for
      # every app module whose classes the value contains.
      def self.dump_value(value, dependencies: {})
        dump(value, Dump.new({}.compare_by_identity, {}.compare_by_identity, dependencies))
      end

      def self.load_value(value, fallback_class: nil)
        load(value, {}.compare_by_identity, fallback_class:)
      end

      def self.dump(value, context)
        # Klenod evaluates module exports inside anonymous modules. Its SVG
        # imports are metadata objects from one of those modules, which Ruby
        # cannot marshal even though an element only needs their URL. Keep the
        # stable string representation in the persisted descriptor instead.
        return value.src if klenod_svg_metadata?(value)

        case value
        in Hash
          value.transform_values { dump(it, context) }
        in Array
          value.map { dump(it, context) }
        in Proc | Async::Task
          nil
        in Class
          dump_component_class(value)
        in Mayu::Component::State
          Mayu::Component::State.new(values: dump(value.marshal_dump, context))
        else
          class_ref = class_ref_for(value.class, context)
          class_ref ? dump_object(value, class_ref, context) : value
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

      # A ClassRef for a class defined in an app module, or nil for any other
      # class or without a resolver. Records the module as a dependency.
      def self.class_ref_for(klass, context)
        return context.class_refs[klass] if context.class_refs.key?(klass)

        resolver = Fiber[COMPONENT_RESOLVER_KEY]
        reference = resolver.class_reference(klass) if resolver.respond_to?(:class_reference)
        class_ref =
          if reference
            module_id, constant_path = reference
            ClassRef.new(module_id, constant_path, resolver.module_digest(module_id))
          end
        context.dependencies[class_ref.module_id] = class_ref.digest if class_ref
        context.class_refs[klass] = class_ref
      end

      def self.dump_object(value, class_ref, context)
        refs = context.refs
        return refs[value] if refs.key?(value)

        ref = refs[value] = ObjectRef.new(class_ref)
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
        ref.payload = dump(payload, context)
        ref
      end

      def self.load_object(ref, objects)
        return objects[ref] if objects.key?(ref)

        klass = resolve_class_ref(ref.class_ref)

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

      def self.resolve_class_ref(class_ref)
        resolver = Fiber[COMPONENT_RESOLVER_KEY]
        unless resolver.respond_to?(:resolve_class)
          raise "No resolver for #{class_ref.constant_path} in #{class_ref.module_id}"
        end

        resolver.resolve_class(class_ref.module_id, class_ref.constant_path)
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
