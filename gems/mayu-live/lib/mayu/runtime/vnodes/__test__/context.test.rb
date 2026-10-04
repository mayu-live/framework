# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::ContextTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class ContextProbe < Mayu::Component::Base
    def render
      H[:p, @__context[:theme][:color]]
    end
  end

  def test_context_helper_scopes_values
    descriptor =
      H[:body, H.context(theme: {color: "red"}) { H[ContextProbe] }]

    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    html = render_html(engine.root)
    assert_match("<p>red</p>", html)
  end

  def test_context_helper_allows_nested_override
    descriptor =
      H[
        :body,
        H.context(theme: {color: "red"}) do
          H.context(theme: {color: "blue"}) { H[ContextProbe] }
        end
      ]

    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    html = render_html(engine.root)
    assert_match("<p>blue</p>", html)
  end

  # Remembers its instance, so a test can read context after rendering, the
  # way an event handler does.
  class HandlerProbe < Mayu::Component::Base
    class << self
      attr_accessor :last
    end

    def initialize
      self.class.last = self
    end

    def theme = @__context[:theme]

    def render
      H[:p, "probe"]
    end
  end

  class Provider < Mayu::Component::Base
    def render
      H.context(theme: {color: @__props[:color]}) { H[:slot] }
    end
  end

  def test_context_is_readable_after_rendering
    descriptor = H[:body, H[Provider, H[HandlerProbe], color: "red"]]

    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    render_html(engine.root)
    assert_equal({color: "red"}, HandlerProbe.last.theme)

    engine.root.update(
      Mayu::Runtime::VNodes::CommandCollector.new,
      H[:body, H[Provider, H[HandlerProbe], color: "blue"]]
    )
    assert_equal({color: "blue"}, HandlerProbe.last.theme)
  end

  def test_context_is_read_only
    descriptor = H[:body, H[HandlerProbe]]
    Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

    error =
      assert_raises(Mayu::Runtime::VNodes::VComponent::Context::ReadOnlyError) do
        HandlerProbe.last.instance_variable_get(:@__context)[:theme] = "dark"
      end
    assert_includes(error.message, "H.context(theme: value)")
  end
end
