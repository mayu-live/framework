# typed: true

require "minitest/autorun"
require "test_helper"
require "rouge"
require "nokogiri"
require_relative "resources/transformers/haml"
require_relative "session"
require_relative "vdom"
require_relative "vdom/vtree"

class Mayu::VDOM::Test < Minitest::Test
  MyComponent = Mayu::TestHelper.haml_to_component(__FILE__, __LINE__, <<~HAML)
    :ruby
      def self.get_initial_state(initial_count: 3, **)
        { count: initial_count }
      end

      def handle_click(e)
        value = e.dig("target", "value").to_i

        update do |state|
          { count: state[:count] + value }
        end
      end

    :css
      .foo { color: peru; }
      .btn { background: peachpuff; }
      .increment { }
      .decrement { }
    .foo
      %button.increment(name="increment" value="1" onclick=handle_click)
        Decrement
      %button.decrement(name="decrement" value="-1" onclick=handle_click)
        Increment
      %output= state[:count]
    HAML

  def test_vdom
    Mayu::TestHelper.test_component(MyComponent) do |page|
      button = page.find_by_css("[name=increment]")
      page.fire_event(button, :click)
      page.debug!
      page.wait_for_update
      page.debug!

      assert_equal(page.to_html, <<~HTML)
        <div class="lib/mayu/vdom.foo">
          <button
            name="increment"
            value="1"
            onclick="Mayu.handle(event,'LckOTvJsohBty1Pm')"
            class="lib/mayu/vdom.increment"
          >
            Decrement
          </button>
          <button
            name="decrement"
            value="-1"
            onclick="Mayu.handle(event,'LckOTvJsohBty1Pm')"
            class="lib/mayu/vdom.decrement"
          >
            Increment
          </button>
          <output>4</output>
        </div>
      HTML
    end
  end
end
