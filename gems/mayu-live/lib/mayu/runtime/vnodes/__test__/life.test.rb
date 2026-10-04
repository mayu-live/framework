# frozen_string_literal: true

require_relative "test_helpers"
require "mayu/build"
require "benchmark"

class Mayu::Runtime::VNodes::LifeTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  def setup
    provider = Mayu::Build::Configuration.new(
      root: File.expand_path("../../../../../../../example", __dir__)
    ).development_provider
    @life = provider.exports(provider.entry("pages/demos/life/Life.haml"))::Default
    @props = {width: 8, height: 8, running: false, fps: 4, rule: "life",
              reset_version: 0, randomize_version: 0, step_version: 0}
  end

  def component(width = 8, height = 8)
    instance = @life.allocate
    instance.instance_variable_set(:@__props, @props.merge(width: width, height: height))
    instance.instance_variable_set(:@__state, Mayu::Component::State.new(instance))
    instance.send(:initialize)
    instance
  end

  def state(instance)
    instance.instance_variable_get(:@__state)
  end

  def reference(grid, width, height, rule)
    Array.new(grid.length) do |index|
      x = index % width
      y = index / width
      count = 0
      (-1..1).each do |dy|
        (-1..1).each do |dx|
          next if dx.zero? && dy.zero?
          count += 1 if grid[((y + dy) % height) * width + (x + dx) % width]
        end
      end
      (grid[index] ? rule.survive : rule.born).include?(count)
    end
  end

  def test_all_presets_match_reference_on_seeded_boards
    random = Random.new(42)
    [[8, 8], [8, 48], [48, 8], [24, 24], [17, 29], [48, 48]].each do |width, height|
      instance = component(width, height)
      @life::RULES.each do |rule|
        instance.instance_variable_set(:@__props, @props.merge(rule: rule.id))
        grid = Array.new(width * height) { random.rand(2).zero? }
        5.times do
          expected = reference(grid, width, height, rule)
          actual = instance.send(:step_grid, grid)
          assert_equal(expected, actual, "#{rule.id} on #{width}x#{height}")
          assert_same(grid, actual) if expected == grid
          grid = actual
        end
      end
    end
    @life::RULE_LOOKUPS.each_value do |lookup|
      assert_predicate(lookup, :frozen?)
      lookup.each do |counts|
        assert_predicate(counts, :frozen?)
        assert_equal(9, counts.length)
      end
    end
  end

  def test_wrapped_blinker_still_life_and_unknown_rule
    instance = component
    grid = @life.init_grid(8, 8) { |x, y| y.zero? && [7, 0, 1].include?(x) }
    expected = @life.init_grid(8, 8) { |x, y| x.zero? && [7, 0, 1].include?(y) }
    assert_equal(expected, instance.send(:step_grid, grid))
    assert_equal(grid, instance.send(:step_grid, expected))
    block = @life.init_grid(8, 8) { |x, y| [7, 0].include?(x) && [7, 0].include?(y) }
    assert_same(block, instance.send(:step_grid, block))
    instance.instance_variable_set(:@__props, @props.merge(rule: "unknown"))
    assert_equal(expected, instance.send(:step_grid, grid))
  end

  def test_controls_and_cache_lifecycle
    engine = Mayu::Runtime::Engine.new(H[:body, H[@life, **@props]], metrics: NullMetrics.new)
    node = find_component(engine.root, @life)
    instance = node.instance_variable_get(:@instance)
    cache = instance.send(:neighbor_positions)
    refute_includes(state(instance).marshal_dump.keys, :neighbor_positions)
    instance.handle_draw(target: {value: "0 0"}, buttons: 1)
    assert(state(instance)[:grid][0])
    instance.handle_draw(target: {value: "0 0"}, buttons: 2)
    refute(state(instance)[:grid][0])
    instance.handle_draw(target: {value: "0 0"}, buttons: 0)
    refute(state(instance)[:grid][0])

    update = lambda do |**changes|
      @props = @props.merge(changes)
      engine.update(H[:body, H[@life, **@props]])
    end
    update.call(randomize_version: 1)
    assert_equal(64, state(instance)[:grid].length)
    assert(state(instance)[:grid].any?)
    assert_same(cache, instance.send(:neighbor_positions))
    update.call(reset_version: 1)
    refute(state(instance)[:grid].any?)
    assert_same(cache, instance.send(:neighbor_positions))
    [2, 3, 4].each { |x| instance.set_cell_value(x, 3, true) }
    grid = state(instance)[:grid]
    update.call(step_version: 1)
    assert_equal(reference(grid, 8, 8, @life::RULES.first), state(instance)[:grid])
    update.call(rule: "seeds")
    grid = state(instance)[:grid]
    update.call(step_version: 2)
    assert_equal(reference(grid, 8, 8, @life::RULES.find { |rule| rule.id == "seeds" }), state(instance)[:grid])
    assert_same(cache, instance.send(:neighbor_positions))
    update.call(width: 12, height: 9)
    assert_equal(108, state(instance)[:grid].length)
    refute(state(instance)[:grid].any?)
    refute_same(cache, instance.send(:neighbor_positions))

    dump = instance.marshal_dump
    refute_includes(dump.keys, :@neighbor_positions)
    restored = @life.allocate
    restored.marshal_load(Marshal.load(Marshal.dump(dump)))
    restored.instance_variable_set(:@__props, @props)
    assert_nil(restored.instance_variable_get(:@neighbor_positions))
    assert_same(state(restored)[:grid], restored.send(:step_grid, state(restored)[:grid]))
    assert_equal(108, restored.send(:neighbor_positions).length)

    # HMR initializes a replacement before applying the previous state dump.
    replacement = component
    replacement.marshal_load(dump)
    replacement.instance_variable_set(:@__props, @props)
    assert_nil(replacement.instance_variable_get(:@neighbor_positions))
    assert_equal(108, replacement.send(:neighbor_positions).length)

    updates = 0
    replacement.define_singleton_method(:update!) { |value|
      updates += 1
      value
    }
    replacement.instance_variable_set(:@neighbor_positions, nil)
    replacement.send(:neighbor_positions)
    assert_equal(0, updates, "cache construction does not queue a render")
  end

  def test_generation_benchmark
    skip "Set MAYU_LIFE_BENCHMARK to benchmark generation" unless ENV["MAYU_LIFE_BENCHMARK"]
    random = Random.new(42)
    [24, 48].each do |size|
      instance = component(size, size)
      instance.instance_variable_set(:@neighbor_positions, nil)
      setup_ms = Benchmark.realtime { instance.send(:neighbor_positions) } * 1000
      grid = Array.new(size * size) { random.rand(2).zero? }
      baseline = -> { reference(grid, size, size, @life::RULES.first) }
      optimized = -> { instance.send(:step_grid, grid) }
      [baseline, optimized].each { |run| 20.times { run.call } }
      median = lambda do |run|
        Array.new(51) { Benchmark.realtime { 10.times { run.call } } * 100 }.sort[25]
      end
      before = median.call(baseline)
      after = median.call(optimized)
      puts "#{size}x#{size} generation median: reference #{before.round(3)}ms; cached #{after.round(3)}ms; speedup #{(before / after).round(2)}x; table setup #{setup_ms.round(3)}ms"
    end
  end
end
