#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"
require_relative "../../../klenod/provider"

# A transferred session restores each component whose code is unchanged, and
# starts over only the components whose code changed or whose state can not
# be restored.
class Mayu::Runtime::VNodes::RestoreTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class Counter < Mayu::Component::Base
    class << self
      # What the first render shows, so a component that starts over
      # renders something else.
      attr_accessor :initial_count
    end

    attr_reader :count

    def initialize
      @count = self.class.initial_count || 0
    end

    def render
      H[:p, "count #{@count}"]
    end
  end

  class Sibling < Counter
  end

  class Parent < Mayu::Component::Base
    def render
      H[:div, H[Counter], H[Sibling]]
    end
  end

  Card = Data.define(:title)

  # Stands in for the module provider of one deploy: which module each class
  # comes from, and the digest of each module's code.
  class Deploy
    MODULES = {
      "app:/parent.haml" => Parent,
      "app:/counter.haml" => Counter,
      "app:/sibling.haml" => Sibling
    }.freeze

    def initialize(digests: {}, components: MODULES, cards: Card)
      @digests = Hash.new("v1").merge(digests)
      @components = components
      @cards = cards
    end

    def component_resolver = self

    def assets_for_module(*, **) = []

    def dump_component_class(klass)
      module_id = @components.key(klass)
      return unless module_id

      Mayu::Runtime::Marshalling::ComponentRef.new(module_id, klass.name.split("::").last, nil, @digests[module_id])
    end

    def resolve_component_ref(reference)
      @components.fetch(reference.filename) do
        raise Mayu::Klenod::UnresolvedClass, "#{reference.filename} is gone"
      end
    end

    def class_reference(klass)
      ["app:/models.rb", "Card"] if klass == Card
    end

    def resolve_class(_module_id, _constant_path)
      @cards or raise Mayu::Klenod::UnresolvedClass, "Card is gone"
    end

    def module_digest(module_id) = @digests[module_id]
  end

  def transfer(to:, counter: 5, sibling: 7, &)
    Counter.initial_count = counter
    Sibling.initial_count = sibling
    engine =
      Mayu::Runtime::Engine.new(H[:body, H[Parent]], metrics: NullMetrics.new, module_provider: Deploy.new)
    dumped = engine.dump
    Counter.initial_count = Sibling.initial_count = nil

    Mayu::Runtime::Engine.restore(dumped, metrics: NullMetrics.new, module_provider: to)
  end

  def instance(engine, klass)
    find_component(engine.root, klass).instance_variable_get(:@instance)
  end

  def test_unchanged_components_keep_their_state
    restored = transfer(to: Deploy.new)

    assert_equal(5, instance(restored, Counter).count)
    assert_equal(7, instance(restored, Sibling).count)
    assert_empty(restored.restore_report.reinitialized)
    assert_empty(restored.restore_report.vnodes_to_update)
  end

  def test_a_changed_component_starts_over_and_renders_again
    restored = transfer(to: Deploy.new(digests: {"app:/counter.haml" => "v2"}))
    report = restored.restore_report

    assert_equal(0, instance(restored, Counter).count)
    assert_equal(7, instance(restored, Sibling).count)
    assert_equal(["app:/counter.haml changed"], report.reinitialized.map(&:reason))
    assert_equal([find_component(restored.root, Counter)], report.vnodes_to_update)

    run_engine_instance(restored) do
      commands = dequeue_until(restored) { |batch| batch.any?(Mayu::Runtime::Commands::SetTextContent) }
      texts = commands.grep(Mayu::Runtime::Commands::SetTextContent).map(&:content)

      assert_equal(["count 0"], texts)
    end
  end

  def test_a_changed_module_of_an_object_in_state_starts_the_component_over
    engine = Mayu::Runtime::Engine.new(H[:body, H[Parent]], metrics: NullMetrics.new, module_provider: Deploy.new)
    instance(engine, Counter).instance_variable_set(:@card, Card.new("A"))
    dumped = engine.dump

    restored = Mayu::Runtime::Engine.restore(
      dumped,
      metrics: NullMetrics.new,
      module_provider: Deploy.new(digests: {"app:/models.rb" => "v2"})
    )

    assert_nil(instance(restored, Counter).instance_variable_get(:@card))
    assert_equal(["app:/models.rb changed"], restored.restore_report.reinitialized.map(&:reason))
  end

  def test_state_that_can_not_be_loaded_starts_only_that_component_over
    engine = Mayu::Runtime::Engine.new(H[:body, H[Parent]], metrics: NullMetrics.new, module_provider: Deploy.new)
    instance(engine, Counter).instance_variable_set(:@card, Card.new("A"))
    instance(engine, Sibling).instance_variable_set(:@count, 7)
    dumped = engine.dump

    restored = Mayu::Runtime::Engine.restore(dumped, metrics: NullMetrics.new, module_provider: Deploy.new(cards: nil))

    assert_equal(7, instance(restored, Sibling).count)
    reasons = restored.restore_report.reinitialized.map(&:reason)
    assert_equal(["Mayu::Klenod::UnresolvedClass: Card is gone"], reasons)
  end

  def test_a_removed_component_is_replaced_when_its_parent_renders
    components = Deploy::MODULES.except("app:/counter.haml")
    restored = transfer(to: Deploy.new(components:))
    report = restored.restore_report

    assert_equal(["app:/counter.haml"], report.unresolved.map { it.reason[/app:\S+/] })
    assert_equal([find_component(restored.root, Parent)], report.vnodes_to_update)
    assert_equal(7, instance(restored, Sibling).count)

    run_engine_instance(restored) do
      dequeue_until(restored) { |batch| !batch.empty? }
    end

    assert_nil(find_component(restored.root, Mayu::Runtime::UnresolvedComponent))
    assert_equal(0, instance(restored, Counter).count)
    assert_equal(7, instance(restored, Sibling).count)
  end
end
