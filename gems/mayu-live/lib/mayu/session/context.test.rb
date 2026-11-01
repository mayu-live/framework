# frozen_string_literal: true

require "minitest/autorun"
require_relative "../runtime"
require_relative "../session"
require "mayu/test"

class Mayu::Session::ContextTest < Minitest::Test
  class Probe < Mayu::Component::Base
    attr_reader :initial_context

    def initialize
      @initial_context = session_context
    end

    def render
      H[:span, session_context.fetch(:label)]
    end
  end

  def test_snapshot_is_detached_and_deeply_frozen
    original = {label: +"private", nested: [{"key" => "value"}]}
    snapshot = Mayu::Session::Context.snapshot(original)
    original[:label].replace("changed")
    assert_equal "private", snapshot[:label]
    assert snapshot.frozen?
    assert snapshot[:nested].first.keys.first.frozen?
    assert_raises(FrozenError) { snapshot[:nested].first["key"].replace("other") }
  end

  def test_invalid_context_is_rejected
    [{"key" => 1}, {key: Object.new}, {key: Float::NAN}].each do |value|
      assert_raises(ArgumentError) { Mayu::Session::Context.snapshot(value) }
    end
    cyclic = {}
    cyclic[:self] = cyclic
    assert_raises(ArgumentError) { Mayu::Session::Context.snapshot(cyclic) }
  end

  def test_context_is_installed_before_initialization_and_separate_from_providers
    engine = Mayu::Runtime::Engine.new(
      Mayu::Runtime::H.context(label: "provider") {
        Mayu::Runtime::H[Probe, session_context: {label: "prop"}]
      },
      metrics: Mayu::Test::FakeMetrics.new,
      session_context: {label: "snapshot", secret: "not in markup"}
    )
    assert_includes engine.render, "snapshot"
    refute_includes engine.render, "not in markup"
  end
end
