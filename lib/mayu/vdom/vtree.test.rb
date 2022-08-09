# typed: true

require "minitest/autorun"
require "test_helper"
require "async"
require "rexml/document"
require "stringio"
require_relative "vtree"
require_relative "h"
require_relative "../state"
require_relative "../fetch"

class TestVTree < Minitest::Test
  include Mayu::VDOM::H

  class MyComponent < Mayu::VDOM::Component::Base
    include Mayu::VDOM::H

    def render
      @lol ||= rand
      h
        .div do
          h.h1 "Hola mundo#{@lol}"
          h.h2 "Hello world"
        end
        .div
    end
  end

  def test_yolo
    Async do |task|
      store = Mayu::State::Store.new({}, reducers: {})
      fetch = Mayu::Fetch.new
      vtree = Mayu::VDOM::VTree.new(store:, fetch:)

      vtree.render(
        h
          .div do
            h.h1 "Title"
            h[MyComponent]
          end
          .div
      )

      vtree.to_html.tap { |html| print_xml(html) }

      puts

      vtree.render(
        h
          .div do
            h.h1 "Title"
            h[MyComponent]
            h.div "foo"
            h[MyComponent]
          end
          .div
      )

      vtree.to_html.tap { |html| print_xml(html) }
    ensure
      vtree&.stop!
    end
  end

  def testx_foo
    Async do |task|
      vtree =
        Mayu::VDOM::VTree.new(
          fetch: Mayu::Fetch.new,
          store: Mayu::State::Store.new({}, reducers: {})
        )

      number_lists = [
        [0, 2, 1, 6, 7, 8, 4, 3, 5],
        [1, 7, 6, 5, 3, 0, 2, 4],
        [1, 3, 123, 0, 4, 2, 9, 32, 455]
      ]

      number_lists.each do |numbers|
        vtree.render(
          h
            .div do
              h.h1 "Hola mundo"
              h.h2 "Hello world"
              h.ul { numbers.each { |num| h.li num, key: num } }.ul
            end
            .div
        )

        html = vtree.to_html
        print_xml(html)
        assert_equal(numbers, extract_numbers(html))
      end
    ensure
      vtree&.stop!
    end
  end

  private

  def print_xml(source)
    io = StringIO.new
    doc = REXML::Document.new(source)
    formatter = REXML::Formatters::Pretty.new
    formatter.compact = true
    formatter.write(doc, io)
    io.rewind

    puts io
           .read
           .gsub(/(mayu-id='?)(\d+)/) { "#{$~[1]}\e[1;34m#{$~[2]}\e[0m" }
           .gsub(/(mayu-key='?)(\d+)/) { "#{$~[1]}\e[1;35m#{$~[2]}\e[0m" }
           .gsub(/>(.*?)</) { ">\e[33m#{$~[1]}\e[0m<" }
  end

  def extract_numbers(source)
    REXML::Document.new(source).get_elements("//li").map(&:text).map(&:to_i)
  end
end
