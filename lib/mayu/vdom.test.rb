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
    component =
      Mayu::TestHelper.haml_to_component(
        <<~HAML,
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
        .increment { background: peachpuff; }
        .decrement { background: peachpuff; }
      .foo
        %button.increment(data-test-id="increment" onclick=handle_click_increment)
          Decrement
        %button.decrement(data-test-id="decrement" onclick=handle_click_decrement)
          Increment
        %output= state[:count]
    HAML
        file: __FILE__,
        line: __LINE__
      )

    Async do |task|
      vtree = Mayu::TestHelper.setup_vtree

      vtree.render(Mayu::VDOM.h(component))
      update_finished = Async::Notification.new

      updater = Mayu::VDOM::VTree::Updater.new(vtree)
      update_task =
        updater.run do |event, payload|
          if event == :update_finished
            update_finished.signal
          else
            Console.logger.info(
              Mayu::VDOM::VTree::Updater,
              event,
              JSON.generate(payload)
            )
          end
        end

      doc = render_document(vtree)
      puts Mayu::TestHelper.format_html(doc.to_html)

      button = doc.at_css("[data-test-id=increment]")
      trigger_event(vtree, button, :click, { type: "click" })

      update_finished.wait

      doc = render_document(vtree)

      assert_equal(Mayu::TestHelper.format_xml(doc.to_html), <<~HTML)
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
    ensure
      update_task&.stop
    end
  end

  private

  CALLBACK_ID_RE = /\AMayu\.handle\(event,'(?<callback_id>\w+)'\)\z/

  def render_document(vtree)
    html = vtree.to_html

    Nokogiri::HTML5::DocumentFragment
      .parse(html)
      .tap { validate_doc(_1, html) }
      .tap { remove_css_hashes(_1) }
      .tap { remove_mayu_id(_1) }
  end

  def validate_doc(doc, html)
    doc.errors.each do |error|
      puts "\e[31m#{error}\e[0m"
      puts format("\e[31m%s\e[0m", error.message)
      puts format("%s\e[0m", html.dup.insert(error.column, "\e[33m"))
    end
  end

  def remove_mayu_id(doc)
    doc
      .css("[data-mayu-id]")
      .each { |elem| elem.remove_attribute("data-mayu-id") }
  end

  def remove_css_hashes(doc)
    doc
      .css("[class]")
      .each { |elem| elem["class"] = elem["class"].gsub(/\?[^$\s]+/, "") }
  end

  def trigger_event(vtree, element, event, payload = {})
    vtree.handle_callback(callback_id(element, "on#{event}"), payload)
  end

  def callback_id(element, attr)
    if match = CALLBACK_ID_RE.match(element[attr])
      match[:callback_id]
    else
      $stderr.puts <<~EOF
        \e[7;31mCould not find an #{attr}-handler:\e[0m
        #{Mayu::TestHelper.format_xml(element.to_html)}
      EOF
      raise "Element does not have an #{attr}-handler: #{element.to_s}"
    end
  end
end
