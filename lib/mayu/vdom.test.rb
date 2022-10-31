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
  def test_vdom
    component = Mayu::TestHelper.haml_to_component(__FILE__, __LINE__, <<~HAML)
      :ruby
        def self.get_initial_state(initial_count: 3, **)
          { count: initial_count }
        end

        def handle_click_increment(e)
          update do |state|
            { count: state[:count] + 1 }
          end
        end

        def handle_click_decrement(e)
          update do |state|
            { count: state[:count] - 1 }
          end
        end

      :css
        .foo { color: peru; }
        .btn { background: peachpuff; }
        .increment { }
        .decrement { }
      .foo
        %button.increment(data-test-id="increment" onclick=handle_click_increment)
          Decrement
        %button.decrement(data-test-id="decrement" onclick=handle_click_decrement)
          Increment
        %output= state[:count]
      HAML

    Async do |task|
      Mayu::TestHelper::Page.run do |page|
        page.render(Mayu::VDOM.h(component))
        page.wait_for_update

        button = page.find_by_test_id("increment")
        page.fire_event(button, :click)

        page.debug!

        page.wait_for_update

        assert_equal(page.to_html, <<~HTML)
          <div class="lib/mayu/vdom.foo">
            <button
              data-test-id=\"increment\"
              onclick=\"Mayu.handle(event,'1PH0HsFv5pGhqXU_')\"
              class=\"lib/mayu/vdom.increment\"
            >
              Decrement
            </button>
            <button
              data-test-id=\"decrement\"
              onclick=\"Mayu.handle(event,'Lw7pLA6l7igSkyvD')\"
              class=\"lib/mayu/vdom.decrement\"
            >
              Increment
            </button>
            <output>4</output>
          </div>
        HTML
      end
    end
  end
end
