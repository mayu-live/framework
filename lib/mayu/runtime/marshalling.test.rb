#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require "async"

require_relative "../component/base"
require_relative "../modules/system"
require_relative "marshalling"

class Mayu::Runtime::Marshalling::Test < Minitest::Test
  Marshalling = Mayu::Runtime::Marshalling

  class ExportedComponent < Mayu::Component::Base
    def self.module_path = "/tests/marshalling/exported"
  end

  class RenamedComponent < Mayu::Component::Base
    def self.module_path = "/tests/marshalling/renamed"
  end

  class LocalComponent < Mayu::Component::Base
  end

  Resolver =
    Data.define(:component_class) do
      def dump_component_class(component)
        return unless component == component_class

        Marshalling::ComponentRef.new(
          "app:/components/exported.haml",
          "ExportedComponent",
          nil
        )
      end

      def resolve_component_ref(reference)
        return unless reference.filename == "app:/components/exported.haml"

        component_class
      end
    end

  def test_dump_value_wraps_component_classes_recursively
    dumped =
      Marshalling.dump_value(
        { exported: ExportedComponent, nested: [LocalComponent] }
      )

    exported_ref = dumped[:exported]
    nested_ref = dumped[:nested].first

    assert_instance_of(Marshalling::ComponentRef, exported_ref)
    assert_equal("/tests/marshalling/exported", exported_ref.filename)
    assert_equal("ExportedComponent", exported_ref.class_name)
    assert_nil(exported_ref.klass)

    assert_instance_of(Marshalling::ComponentRef, nested_ref)
    assert_nil(nested_ref.filename)
    assert_equal("LocalComponent", nested_ref.class_name)
    assert_equal(LocalComponent, nested_ref.klass)
  end

  def test_load_value_prefers_named_export_when_present
    with_module_system(
      "/tests/marshalling/exported" => build_mod(ExportedComponent)
    ) do
      ref =
        Marshalling::ComponentRef.new(
          "/tests/marshalling/exported",
          "ExportedComponent",
          nil
        )

      assert_equal(ExportedComponent, Marshalling.load_value(ref))
    end
  end

  def test_load_value_falls_back_to_default_export_when_name_is_missing
    with_module_system(
      "/tests/marshalling/renamed" => build_mod(RenamedComponent, named: false)
    ) do
      ref =
        Marshalling::ComponentRef.new(
          "/tests/marshalling/renamed",
          "OldComponentName",
          nil
        )

      assert_equal(RenamedComponent, Marshalling.load_value(ref))
    end
  end

  def test_load_value_uses_fallback_class_for_pathless_reference
    ref = Marshalling::ComponentRef.new(nil, "MissingClass", nil)
    assert_equal(
      LocalComponent,
      Marshalling.load_value(ref, fallback_class: LocalComponent)
    )
  end

  def test_component_resolver_uses_canonical_module_ids
    resolver = Resolver.new(ExportedComponent)

    Marshalling.with_component_resolver(resolver) do
      reference = Marshalling.dump_value(ExportedComponent)

      assert_equal("app:/components/exported.haml", reference.filename)
      assert_nil(reference.klass)
      assert_equal(ExportedComponent, Marshalling.load_value(reference))
    end
  end

  def test_component_resolver_scope_is_restored
    resolver = Resolver.new(ExportedComponent)

    Marshalling.with_component_resolver(resolver) do
      assert_equal(
        "app:/components/exported.haml",
        Marshalling.dump_value(ExportedComponent).filename
      )
    end

    assert_equal(
      "/tests/marshalling/exported",
      Marshalling.dump_value(ExportedComponent).filename
    )
  end

  def test_dump_value_serializes_proc_as_nil
    dumped =
      Marshalling.dump_value(
        { callback: -> {}, nested: [-> {}, { fn: -> {} }] }
      )

    assert_nil(dumped[:callback])
    assert_equal([nil, { fn: nil }], dumped[:nested])
  end

  def test_dump_value_serializes_async_task_as_nil
    Async do |task|
      dumped = Marshalling.dump_value({ task: task, nested: [task] })

      assert_nil(dumped[:task])
      assert_equal([nil], dumped[:nested])
    end.wait
  end

  private

  def build_mod(component_class, named: true)
    mod = Module.new
    exports = Module.new
    exports.const_set(:Default, component_class)
    if named
      exports.const_set(component_class.name.split("::").last, component_class)
    end
    mod.const_set(:Exports, exports)
    mod
  end

  def with_module_system(mods)
    system =
      Data
        .define(:mods) do
          def get_mod(path)
            mods[path]
          end

          def import(path, _source = "/")
            mod = mods[path]
            raise "Missing module #{path.inspect}" unless mod
            mod::Exports::Default
          end
        end
        .new(mods)

    key = Mayu::Modules::System::CURRENT_KEY
    previous = Thread.current.thread_variable_get(key)
    Thread.current.thread_variable_set(key, system)

    yield
  ensure
    Thread.current.thread_variable_set(key, previous)
  end
end
