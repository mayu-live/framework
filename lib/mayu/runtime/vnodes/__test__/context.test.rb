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
      H[:body, H.context(theme: { color: "red" }) { H[ContextProbe] }]

    with_modules_system(ContextProbe) do
      engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
      html = render_html(engine.root)
      assert_match("<p>red</p>", html)
    end
  end

  def test_context_helper_allows_nested_override
    descriptor =
      H[
        :body,
        H.context(theme: { color: "red" }) do
          H.context(theme: { color: "blue" }) { H[ContextProbe] }
        end
      ]

    with_modules_system(ContextProbe) do
      engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
      html = render_html(engine.root)
      assert_match("<p>blue</p>", html)
    end
  end
end
