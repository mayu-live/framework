#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require "mayu/test"
require_relative "recorder"

class Mayu::Devtools::RecorderTest < Minitest::Test
  # Remembers what reaches the wrapped metrics.
  class SpyMetrics < Mayu::Test::FakeMetrics
    attr_reader :calls

    def initialize
      @calls = []
    end

    def update_summary(summary, labels: {})
      @calls << [summary.class, labels]
      yield
    end
  end

  FakeEngine = Struct.new(:metrics)

  def test_install_wraps_the_metrics_once
    engine = FakeEngine.new(SpyMetrics.new)

    recorder = Mayu::Devtools::Recorder.install(engine)

    assert_same(recorder, engine.metrics)
    assert_same(recorder, Mayu::Devtools::Recorder.install(engine))
  end

  def test_renders_reconciles_and_callbacks_are_timed
    spy = SpyMetrics.new
    recorder = Mayu::Devtools::Recorder.new(spy)

    2.times do
      recorder.update_summary(recorder.component_render_duration_ms, labels: {component: "Counter"}) { :rendered }
    end
    recorder.update_summary(recorder.component_reconcile_duration_ms, labels: {component: "Counter"}) {}
    recorder.update_summary(recorder.callback_handler_duration_ms, labels: {component: "Counter", method: :increment}) {}

    render = recorder.timings[:render]["Counter"]
    assert_equal(2, render.count)
    assert_operator(render.total_ms, :>=, render.max_ms)
    assert_equal(1, recorder.timings[:reconcile]["Counter"].count)
    assert_equal(1, recorder.timings[:callback][["Counter", :increment]].count)
  end

  def test_everything_reaches_the_wrapped_metrics
    spy = SpyMetrics.new
    recorder = Mayu::Devtools::Recorder.new(spy)

    result = recorder.update_summary(recorder.component_render_duration_ms, labels: {component: "Counter"}) { :rendered }
    recorder.update_summary(recorder.callback_queue_duration_ms, labels: {component: "Counter"}) {}

    assert_equal(:rendered, result)
    # The wrapped metrics get their own summaries back, not the tagged ones.
    assert_equal(
      [
        [Mayu::Test::FakeMetrics::NullSummary, {component: "Counter"}],
        [Mayu::Test::FakeMetrics::NullSummary, {component: "Counter"}]
      ],
      spy.calls
    )
    assert_empty(recorder.timings[:callback])
  end

  def test_timings_are_kept_when_the_block_raises
    recorder = Mayu::Devtools::Recorder.new(SpyMetrics.new)

    assert_raises(RuntimeError) do
      recorder.update_summary(recorder.component_render_duration_ms, labels: {component: "Broken"}) { raise "boom" }
    end

    assert_equal(1, recorder.timings[:render]["Broken"].count)
  end

  def test_reset_clears_timings
    recorder = Mayu::Devtools::Recorder.new(SpyMetrics.new)
    recorder.update_summary(recorder.component_render_duration_ms, labels: {component: "Counter"}) {}

    recorder.reset

    assert_empty(recorder.timings[:render])
  end
end
