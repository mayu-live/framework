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
require_relative "../klenod/provider"

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

  # Stands in for a module provider: classes are registered under a module id
  # and constant path, the way Klenod exports them.
  class AppResolver
    attr_reader :digests

    def initialize(classes, digests: Hash.new("digest"))
      @classes = classes
      @digests = digests
    end

    def class_reference(klass)
      @classes.key(klass)
    end

    def resolve_class(module_id, constant_path)
      @classes.fetch([module_id, constant_path])
    end

    def module_digest(module_id)
      @digests[module_id]
    end

    def dump_component_class(_) = nil
  end

  def card_class
    Class.new do
      attr_accessor :title, :other
    end
  end

  def app(**classes)
    AppResolver.new(classes.to_h { |name, klass| [["app:/models.rb", name.to_s], klass] })
  end

  # Dumps with one resolver and loads with another, the way a session moves
  # to another process, maybe running newer code.
  def transfer(value, from:, to:)
    dumped = Marshalling.with_component_resolver(from) { Marshal.dump(Marshalling.dump_value(value)) }
    Marshalling.with_component_resolver(to) { Marshalling.load_value(Marshal.load(dumped)) }
  end

  def test_instances_of_app_classes_are_rebuilt_from_the_class_their_reference_names
    old_card = card_class
    card = old_card.new
    card.title = "A"
    new_card = card_class

    loaded = transfer({card:}, from: app("Kanban::Card": old_card), to: app("Kanban::Card": new_card))[:card]

    assert_instance_of(new_card, loaded)
    assert_equal("A", loaded.title)
  end

  def test_instances_of_anonymous_classes_can_be_transferred
    klass = card_class
    card = klass.new
    assert_raises(TypeError) { Marshal.dump(card) }

    loaded = transfer([card], from: app("Kanban::Card": klass), to: app("Kanban::Card": klass))

    assert_instance_of(klass, loaded.first)
  end

  def test_data_instances_are_rebuilt
    item = Data.define(:id, :done)
    current = Data.define(:id, :done)

    loaded = transfer([item.new(id: 1, done: true)], from: app(Item: item), to: app(Item: current))

    assert_equal(current.new(id: 1, done: true), loaded.first)
  end

  def test_objects_keep_their_references_to_each_other
    klass = card_class
    a = klass.new
    b = klass.new
    a.other = b
    b.other = a

    loaded = transfer({a:, b:}, from: app(Card: klass), to: app(Card: card_class))

    assert_same(loaded[:b], loaded[:a].other)
    assert_same(loaded[:a], loaded[:b].other)
  end

  def test_state_values_are_rebuilt
    klass = card_class
    card = klass.new
    card.title = "A"
    current = card_class

    state = transfer(Mayu::Component::State.new(values: {card:}), from: app(Card: klass), to: app(Card: current))

    assert_instance_of(current, state[:card])
    assert_equal("A", state[:card].title)
  end

  def test_dumping_collects_the_modules_a_value_depends_on
    resolver = app(Card: card_class)
    resolver.digests["app:/models.rb"] = "abc"
    dependencies = {}

    Marshalling.with_component_resolver(resolver) do
      Marshalling.dump_value({cards: [resolver.resolve_class("app:/models.rb", "Card").new]}, dependencies:)
    end

    assert_equal({"app:/models.rb" => "abc"}, dependencies)
  end

  class Outside
  end

  def test_other_classes_are_left_alone
    outside = Outside.new

    Marshalling.with_component_resolver(app(Card: card_class)) do
      assert_same(outside, Marshalling.dump_value([outside]).first)
    end
  end

  def test_a_class_that_no_longer_resolves_fails_the_load
    klass = card_class
    missing = Class.new(AppResolver) { def resolve_class(*) = raise(Mayu::Klenod::UnresolvedClass, "gone") }

    assert_raises(Mayu::Klenod::UnresolvedClass) do
      transfer([klass.new], from: app(Card: klass), to: missing.new({}))
    end
  end
end
