# typed: true

require "minitest/autorun"
require "test_helper"
require "async"
require "rexml/document"
require "stringio"
require_relative "vtree"
require_relative "../session"
require_relative "../app_metrics"

class TestVTree < Minitest::Test
  H = Mayu::VDOM::Descriptor

  MyComponent = Mayu::TestHelper.haml_to_component(__FILE__, __LINE__, <<~HAML)
    %div
      %h1 Hola mundo #{@lol ||= rand}
      %pre= props[:count]
  HAML

  def test_component_reuse
    Mayu::TestHelper.test_component(MyComponent, count: 0) do |page|
      # page.debug!
      original_text = page.find_by_css("h1")&.inner_text

      page.render(H[MyComponent, count: 1])
      page.wait_for_update
      # page.debug!
      assert_equal(page.find_by_css("h1")&.inner_text, original_text)

      page.render(H[MyComponent, count: 2])
      page.wait_for_update

      # page.debug!
      assert_equal(page.find_by_css("h1")&.inner_text, original_text)
    end
  end

  def test_list_ordering
    component = Mayu::TestHelper.haml_to_component(__FILE__, __LINE__, <<~HAML)
      %div
        %h1 Hello world
        %ul
          = props[:numbers].map do |num|
            %li(key=num)= num
    HAML

    number_lists = [
      [0, 2, 1, 6, 7, 8, 4, 3, 5],
      [1, 7, 6, 5, 3, 0, 2, 4],
      [1, 3, 123, 0, 4, 2, 9, 32, 455]
    ]

    Mayu::TestHelper.test_component(component, numbers: []) do |page|
      number_lists.each do |numbers|
        page.render(H[component, numbers:])
        assert_equal(numbers, extract_numbers(page.to_html))
        # page.debug!
      end
    end
  end

  private

  def extract_numbers(source)
    REXML::Document.new(source).get_elements("//li").map(&:text).map(&:to_i)
  end
end
