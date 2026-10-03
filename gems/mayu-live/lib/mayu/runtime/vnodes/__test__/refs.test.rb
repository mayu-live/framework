#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::RefsTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class InputProbe < Mayu::Component::Base
    class << self
      attr_accessor :current_in_mount
    end

    attr_reader :input_ref

    def initialize
      @input_ref = Ref.new
      @count = 0
    end

    def mount
      self.class.current_in_mount = @input_ref.current
    end

    def render
      H[:div, H[:input, ref: @input_ref, name: "q"], H[:p, "Count #{@count}"]]
    end

    def handle_submit
      @count += 1
      rerender!
      @input_ref.current.reset
    end
  end

  class Child < Mayu::Component::Base
    def render = H[:p, "child"]
  end

  class Parent < Mayu::Component::Base
    class << self
      attr_accessor :child_in_mount
    end

    attr_reader :child_ref

    def initialize
      @child_ref = Ref.new
    end

    def mount
      self.class.child_in_mount = @child_ref.current
    end

    def render = H[:div, H[Child, ref: @child_ref]]
  end

  class Toggle < Mayu::Component::Base
    attr_reader :ref

    def initialize
      @ref = Ref.new
      @shown = true
      @key = 1
    end

    def render
      H[:div, (H[:input, key: @key, ref: @ref] if @shown)]
    end

    def hide
      @shown = false
      rerender!
    end

    def rekey
      @key += 1
      rerender!
    end
  end

  def test_an_element_ref_is_set_once_the_element_starts
    InputProbe.current_in_mount = nil
    engine = Mayu::Runtime::Engine.new(H[:body, H[InputProbe]], metrics: NullMetrics.new)
    probe = instance(engine, InputProbe)

    assert_nil(probe.input_ref.current)

    run_engine_instance(engine) do
      wait_until { InputProbe.current_in_mount }

      assert_instance_of(Mayu::Runtime::ElementHandle, probe.input_ref.current)
      assert_same(probe.input_ref.current, InputProbe.current_in_mount)
    end
  end

  def test_calling_a_method_on_an_element_sends_it_to_the_browser
    run_engine(H[:body, H[InputProbe]]) do |engine|
      probe = instance(engine, InputProbe)
      wait_until { probe.input_ref.attached? }

      assert_nil(probe.input_ref.current.focus(prevent_scroll: true))

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      assert_equal(
        [
          Mayu::Runtime::Commands::ElementCall[
            find_element(engine.root, :input).dom_id,
            "focus",
            [{preventScroll: true}]
          ]
        ],
        batch.commands
      )
    end
  end

  def test_element_calls_follow_the_dom_updates_queued_before_them
    run_engine(H[:body, H[InputProbe]]) do |engine|
      probe = instance(engine, InputProbe)
      wait_until { probe.input_ref.attached? && probe.respond_to?(:rerender!) }

      probe.handle_submit

      commands = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }.commands
      text = commands.index { it.is_a?(Mayu::Runtime::Commands::SetTextContent) }
      call = commands.index { it.is_a?(Mayu::Runtime::Commands::ElementCall) }

      refute_nil(text)
      refute_nil(call)
      assert_operator(text, :<, call)
      assert_equal("reset", commands[call].method)
    end
  end

  def test_ref_is_not_rendered_as_an_attribute_or_passed_as_a_prop
    engine = Mayu::Runtime::Engine.new(H[:body, H[InputProbe], H[Parent]], metrics: NullMetrics.new)

    html = render_html(engine.root)
    child = instance(engine, Child)

    assert_includes(html, %(<input name="q">))
    refute_includes(html, "ref")
    refute(child.instance_variable_get(:@__props).key?(:ref))
  end

  def test_a_component_ref_is_its_instance_and_set_before_the_parent_mounts
    Parent.child_in_mount = nil

    run_engine(H[:body, H[Parent]]) do |engine|
      wait_until { Parent.child_in_mount }

      assert_same(instance(engine, Child), Parent.child_in_mount)
      assert_same(instance(engine, Child), instance(engine, Parent).child_ref.current)
    end
  end

  def test_removing_an_element_clears_its_ref
    run_engine(H[:body, H[Toggle]]) do |engine|
      toggle = instance(engine, Toggle)
      wait_until { toggle.ref.attached? && toggle.respond_to?(:rerender!) }

      toggle.hide
      Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }

      assert_nil(toggle.ref.current)
    end
  end

  # The new element starts before the old one stops, and stopping the old
  # one must not clear the ref.
  def test_a_new_key_moves_the_ref_to_the_new_element
    run_engine(H[:body, H[Toggle]]) do |engine|
      toggle = instance(engine, Toggle)
      wait_until { toggle.ref.attached? && toggle.respond_to?(:rerender!) }
      old_id = find_element(engine.root, :input).dom_id

      toggle.rekey
      Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      new_id = find_element(engine.root, :input).dom_id
      toggle.ref.current.focus

      call = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }.commands.first
      refute_equal(old_id, new_id)
      assert_equal(new_id, call.id)
    end
  end

  def test_restore_points_state_and_rendered_ref_at_the_same_element
    InputProbe.current_in_mount = nil
    engine =
      Mayu::Runtime::Engine.new(H[:body, H[InputProbe]], metrics: NullMetrics.new, module_provider: Deploy.new)
    restored =
      Mayu::Runtime::Engine.restore(engine.dump, metrics: NullMetrics.new, module_provider: Deploy.new)

    state_ref = instance(restored, InputProbe).input_ref
    element = find_element(restored.root, :input)
    assert_same(state_ref, element.instance_variable_get(:@ref))

    run_engine_instance(restored) do
      wait_until { InputProbe.current_in_mount }

      InputProbe.current_in_mount.focus
      call = Async::Task.current.with_timeout(0.5) { restored.dequeue_batch }.commands.first
      assert_equal(element.dom_id, call.id)
    end
  end

  def test_migrated_state_keeps_the_attached_refs
    run_engine(H[:body, H[InputProbe]]) do |engine|
      probe = instance(engine, InputProbe)
      wait_until { probe.input_ref.attached? }

      migrated = engine.migrate_component_state(probe.marshal_dump)

      assert_same(probe.input_ref, migrated.fetch(:@input_ref))
    end
  end

  def test_a_ref_marshals_as_its_id
    ref = Mayu::Runtime::Ref.new
    copy = Marshal.load(Marshal.dump(ref))

    assert_equal(ref, copy)
    assert_equal(ref.hash, copy.hash)
    refute(copy.attached?)
  end

  def test_an_element_handle_can_not_be_stored
    engine = Mayu::Runtime::Engine.new(H[:body, H[:input]], metrics: NullMetrics.new)
    handle = Mayu::Runtime::ElementHandle.new(find_element(engine.root, :input))

    assert_raises(TypeError) { Marshal.dump(handle) }
  end

  def test_an_element_dumped_before_refs_loads_without_one
    element = Mayu::Runtime::Descriptors::Element.allocate
    element.send(:marshal_load, [:div, nil, nil, Mayu::Runtime::Descriptors::Children[[]], {}])

    assert_nil(element.ref)
    assert_equal(:div, element.type)
  end

  private

  def instance(engine, klass)
    find_component(engine.root, klass).instance_variable_get(:@instance)
  end

  # Lets an engine with these test components be dumped and restored, like
  # the module provider of a deploy.
  class Deploy
    MODULES = {"app:/input_probe.haml" => InputProbe}.freeze

    def component_resolver = self

    def assets_for_module(*, **) = []

    def module_digest(_module_id) = "v1"

    def dump_component_class(klass)
      module_id = MODULES.key(klass) or return
      Mayu::Runtime::Marshalling::ComponentRef.new(module_id, klass.name.split("::").last, nil, "v1")
    end

    def resolve_component_ref(reference) = MODULES.fetch(reference.filename)

    def class_reference(_klass) = nil

    def resolve_class(*) = nil
  end
end
