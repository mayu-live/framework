#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes2::ErrorBoundaryTest < Minitest::Test
  include Mayu::Runtime::VNodes2::TestHelpers

  class ErrorChild < Mayu::Component::Base
    def render
      raise "boom" if @__props[:should_fail]
      H[:span, "ok"]
    end
  end

  class ErrorBoundaryProbe < Mayu::Component::Base
    def initialize
      @should_fail = false
      @handled = false
    end

    def handle_error(_error)
      @handled = true
      true
    end

    def trigger_error
      @should_fail = true
      rerender!
    end

    def render
      return H[:div, "Error handled"] if @handled
      H[ErrorChild, should_fail: @should_fail]
    end
  end

  def test_error_boundary_rerenders_on_error
    descriptor = H[:body, H[ErrorBoundaryProbe]]

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, ErrorBoundaryProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.trigger_error

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      refute_nil(patches)

      html = render_html(engine.root)
      assert_match("<div>Error handled</div>", html)
    end
  end

  def test_error_boundary_render_html
    descriptor = H[:body, H[ErrorBoundaryProbe]]
    engine =
      Mayu::Runtime::VNodes2::Engine.new(descriptor, metrics: NullMetrics.new)

    component = find_component(engine.root, ErrorBoundaryProbe)
    instance = component.instance_variable_get(:@instance)
    instance.instance_variable_set(:@should_fail, true)

    html = render_html(engine.root)
    assert_match("<div>Error handled</div>", html)
  end
end
