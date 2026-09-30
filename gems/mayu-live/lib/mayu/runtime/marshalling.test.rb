#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "minitest/autorun"
require "async"

require_relative "../component/base"
require_relative "marshalling"

class Mayu::Runtime::Marshalling::Test < Minitest::Test
  Marshalling = Mayu::Runtime::Marshalling

  class ExportedComponent < Mayu::Component::Base
    def self.module_path = "/tests/marshalling/exported"
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
        {exported: ExportedComponent, nested: [LocalComponent]}
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
        {callback: -> {}, nested: [-> {}, {fn: -> {}}]}
      )

    assert_nil(dumped[:callback])
    assert_equal([nil, {fn: nil}], dumped[:nested])
  end

  def test_dump_value_serializes_async_task_as_nil
    Async do |task|
      dumped = Marshalling.dump_value({task: task, nested: [task]})

      assert_nil(dumped[:task])
      assert_equal([nil], dumped[:nested])
    end.wait
  end

  # Hot reload evaluates a module again, so its constants name new classes
  # while state still holds instances of the old ones. These tests stand in
  # for a module under Mayu::ModuleNamespace and replace its classes.
  module Mayu::ModuleNamespace
    module MarshallingTest
    end
  end

  Reloaded = Mayu::ModuleNamespace::MarshallingTest

  def reload(name, klass)
    Reloaded.send(:remove_const, name) if Reloaded.const_defined?(name, false)
    Reloaded.const_set(name, klass)
  end

  def round_trip(value)
    Marshalling.load_value(Marshal.load(Marshal.dump(Marshalling.dump_value(value))))
  end

  def card_class
    Class.new do
      attr_accessor :title, :other
    end
  end

  def test_instances_of_replaced_classes_are_rebuilt_from_the_current_class
    card = reload(:Card, card_class).new
    card.title = "A"
    current = reload(:Card, card_class)

    assert_raises(TypeError) { Marshal.dump(card) }

    loaded = round_trip({card:})[:card]
    assert_instance_of(current, loaded)
    assert_equal("A", loaded.title)
  end

  def test_data_instances_of_replaced_classes_are_rebuilt
    item = reload(:Item, Data.define(:id, :done)).new(id: 1, done: true)
    current = reload(:Item, Data.define(:id, :done))

    assert_equal(current.new(id: 1, done: true), round_trip([item]).first)
  end

  def test_replaced_objects_keep_their_references_to_each_other
    a = reload(:Card, card_class).new
    b = a.class.new
    a.other = b
    b.other = a
    reload(:Card, card_class)

    loaded = round_trip({a:, b:})
    assert_same(loaded[:b], loaded[:a].other)
    assert_same(loaded[:a], loaded[:b].other)
  end

  def test_state_values_are_rebuilt
    card = reload(:Card, card_class).new
    card.title = "A"
    current = reload(:Card, card_class)

    state = round_trip(Mayu::Component::State.new(values: {card:}))
    assert_instance_of(current, state[:card])
    assert_equal("A", state[:card].title)
  end

  def test_instances_of_current_classes_are_left_alone
    card = reload(:Card, card_class).new

    assert_same(card, Marshalling.dump_value([card]).first)
  end

  class Outside
  end

  def test_classes_outside_the_module_namespace_are_left_alone
    outside = Outside.new

    assert_same(outside, Marshalling.dump_value([outside]).first)
  end
end
