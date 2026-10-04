# frozen_string_literal: true

require_relative "test_helpers"
require "mayu/build"

class Mayu::Runtime::VNodes::ShouldUpdateTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class Probe < Mayu::Component::Base
    attr_reader :renders, :seen_props

    def initialize
      @renders = 0
    end

    def should_update?(next_props)
      @seen_props = [@__props, next_props]
      raise "hook failed" if next_props[:fail]
      next_props[:value] != @__props[:value]
    end

    def render
      @renders += 1
      H[:div, @__props[:value].to_s, *@__children.descriptors]
    end
  end

  def test_rejection_commits_props_and_local_updates_bypass_the_hook
    engine = Engine.new(H[:body, H[Probe, value: 1]], metrics: NullMetrics.new)
    node = find_component(engine.root, Probe)
    instance = node.instance_variable_get(:@instance)
    engine.update(H[:body, H[Probe, value: 1, extra: "new"]])
    assert_equal(1, instance.renders)
    assert_equal("new", instance.instance_variable_get(:@__props)[:extra])
    assert_nil(instance.seen_props.first[:extra])
    node.update(Mayu::Runtime::VNodes::CommandCollector.new)
    assert_equal(2, instance.renders)
    engine.update(H[:body, H[Probe, value: 2]])
    assert_equal(3, instance.renders)
  end

  def test_children_and_forced_updates_bypass_the_hook
    engine = Engine.new(H[:body, H[Probe, value: 1]], metrics: NullMetrics.new)
    instance = find_component(engine.root, Probe).instance_variable_get(:@instance)
    engine.update(H[:body, H[Probe, H[:span, "child", slot: :content], value: 1]])
    assert_equal(2, instance.renders)
    engine.force_render do
      engine.update(H[:body, H[Probe, H[:span, "child", slot: :content], value: 1]])
    end
    assert_equal(3, instance.renders)
  end

  def test_hook_errors_use_component_error_handling
    engine = Engine.new(H[:body, H[Probe, value: 1]], metrics: NullMetrics.new)
    node = find_component(engine.root, Probe)
    error = assert_raises(Mayu::Runtime::VNodes::VComponent::UnhandledRenderError) do
      node.update(Mayu::Runtime::VNodes::CommandCollector.new, H[Probe, value: 1, fail: true])
    end
    assert_equal("hook failed", error.error.message)
    assert_same(node, error.component)
  end

  Engine = Mayu::Runtime::Engine

  class Consumer < Probe
    def should_update?(next_props) = false

    def render
      super
      H[:output, @__context[:theme].to_s]
    end
  end

  def test_context_changes_bypass_a_rejecting_hook
    descriptor = ->(theme) { H[:body, H.context(theme: theme) { H[Consumer, value: 1] }] }
    engine = Engine.new(descriptor.call("light"), metrics: NullMetrics.new)
    instance = nil
    engine.root.send(:traverse) do |node|
      candidate = node.instance_variable_get(:@instance)
      instance = candidate if candidate.is_a?(Consumer)
    end
    engine.update(descriptor.call("dark"))
    assert_equal(2, instance.renders)
    assert_includes(render_html(engine.root), "dark")
  end

  def test_queued_local_rerender_works_after_parent_rejection
    run_engine(H[:body, H[Probe, value: 1]]) do |engine|
      instance = find_component(engine.root, Probe).instance_variable_get(:@instance)
      wait_until { instance.singleton_methods.include?(:rerender!) }
      engine.update(H[:body, H[Probe, value: 1, extra: "new"]])
      instance.send(:rerender!)
      wait_until { instance.renders == 2 }
      assert_equal("new", instance.instance_variable_get(:@__props)[:extra])
    end
  end

  def test_life_renders_only_changed_cells_and_skips_stable_generations
    provider = Mayu::Build::Configuration.new(
      root: File.expand_path("../../../../../../../example", __dir__)
    ).development_provider
    life = provider.exports(provider.entry("pages/demos/life/Life.haml"))::Default
    cell = provider.exports(provider.entry("pages/demos/life/Cell.haml"))::Default
    renders = 0
    cell.prepend(Module.new do
      define_method(:render) do
        renders += 1
        super()
      end
    end)

    [24, 48].each do |size|
      props = {width: size, height: size, running: false, fps: 4, rule: "life",
               reset_version: 0, randomize_version: 0, step_version: 0}
      engine = Engine.new(H[:body, H[life, **props]], metrics: NullMetrics.new, update_budget: Float::INFINITY)
      node = find_component(engine.root, life)
      instance = node.instance_variable_get(:@instance)
      state = instance.instance_variable_get(:@__state)
      grid = state[:grid]
      instance.handle_step
      assert_same(grid, state[:grid], "empty generation preserves the grid")
      instance.set_cell_value(0, 0, false)
      assert_same(grid, state[:grid], "redundant draw preserves the grid")

      [2, 3, 4].each { |x| instance.set_cell_value(x, 3, true) }
      node.update(Mayu::Runtime::VNodes::CommandCollector.new)
      before = renders
      instance.handle_step
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      node.update(Mayu::Runtime::VNodes::CommandCollector.new)
      optimized_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      assert_equal(4, renders - before, "blinker changes only four cells at #{size}x#{size}")
      before = renders
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      engine.force_render { node.update(Mayu::Runtime::VNodes::CommandCollector.new) }
      baseline_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      assert_equal(size * size, renders - before, "forced baseline renders every cell")
      if ENV["MAYU_LIFE_BENCHMARK"]
        puts "#{size}x#{size} blinker reconciliation: all cells #{(baseline_time * 1000).round(2)}ms; changed cells #{(optimized_time * 1000).round(2)}ms"
      end

      engine.update(H[:body, H[life, **props.merge(reset_version: 1)]])
      before = renders
      engine.update(H[:body, H[life, **props.merge(reset_version: 1, fps: 8)]])
      assert_equal(before, renders, "control updates leave an unchanged grid alone")

      [[2, 2], [3, 2], [2, 3], [3, 3]].each do |x, y|
        instance.set_cell_value(x, y, true)
      end
      node.update(Mayu::Runtime::VNodes::CommandCollector.new)
      grid = state[:grid]
      instance.handle_step
      assert_same(grid, state[:grid], "still life preserves the grid")

      random = Random.new(42)
      size.times do |y|
        size.times { |x| instance.set_cell_value(x, y, random.rand(2).zero?) }
      end
      node.update(Mayu::Runtime::VNodes::CommandCollector.new)
      grid = state[:grid]
      instance.handle_step
      changed = grid.zip(state[:grid]).count { |a, b| a != b }
      before = renders
      node.update(Mayu::Runtime::VNodes::CommandCollector.new)
      assert_equal(changed, renders - before, "random board renders only changed cells")
    end
  end

  def test_life_cell_rerenders_when_callback_or_forwarded_attributes_change
    provider = Mayu::Build::Configuration.new(
      root: File.expand_path("../../../../../../../example", __dir__)
    ).development_provider
    cell = provider.exports(provider.entry("pages/demos/life/Cell.haml"))::Default
    source = Probe.new
    callback = H.callback(source, :render)
    props = {x: 0, y: 0, alive: false, ondraw: callback}
    engine = Engine.new(H[:body, H[cell, **props]], metrics: NullMetrics.new)
    instance = find_component(engine.root, cell).instance_variable_get(:@instance)
    refute(instance.should_update?(props))
    assert(instance.should_update?(props.merge(ondraw: H.callback(source, :should_update?))))
    assert(instance.should_update?(props.merge(title: "changed")))
  end
end
