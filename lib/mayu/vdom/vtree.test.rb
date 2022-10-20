# typed: true

require "minitest/autorun"
require "test_helper"
require "async"
require "rexml/document"
require "stringio"
require_relative "vtree"
require_relative "h"
require_relative "../session"
require_relative "../app_metrics"

class TestVTree < Minitest::Test
  include Mayu::VDOM::H

  class MyComponent < Mayu::Component::Base
    include Mayu::VDOM::H

    def render
      @lol ||= rand
      h.div do
        h.h1 "Hola mundo#{@lol}"
        h.h2 "Hello world"
      end
    end
  end

  def test_yolo
    Async do |task|
      vtree = setup_vtree

      vtree.render(
        h.div do
          h.h1 "Title"
          h[MyComponent]
        end
      )

      vtree.to_html.tap { |html| print_xml(html) }

      puts

      vtree.render(
        h.div do
          h.h1 "Title"
          h[MyComponent]
          h.div "foo"
          h[MyComponent]
        end
      )

      vtree.to_html.tap { |html| print_xml(html) }
    end
  end

  def testx_foo
    Async do |task|
      vtree = setup_vtree

      number_lists = [
        [0, 2, 1, 6, 7, 8, 4, 3, 5],
        [1, 7, 6, 5, 3, 0, 2, 4],
        [1, 3, 123, 0, 4, 2, 9, 32, 455]
      ]

      number_lists.each do |numbers|
        vtree.render(
          h.div do
            h.h1 "Hola mundo"
            h.h2 "Hello world"
            h.ul { numbers.each { |num| h.li num, key: num } }
          end
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

  def setup_vtree
    $metrics ||= Mayu::AppMetrics.setup(Prometheus::Client.registry)
    config =
      Mayu::Configuration.from_hash!(
        { "mode" => :test, "root" => "/laiehbaleihf", "secret_key" => "test" }
      )
    environment = Mayu::Environment.new(config, $metrics)

    environment.instance_eval do
      def load_root(path)
        Mayu::VDOM::Descriptor.new(:div)
      end
      def match_route(path)
      end
    end

    session = Mayu::Session.new(environment:, path: "/")
    Mayu::VDOM::VTree.new(session:)
  end

  def print_xml(source)
    io = StringIO.new
    doc = REXML::Document.new(source)
    formatter = REXML::Formatters::Pretty.new
    formatter.compact = true
    formatter.write(doc, io)
    io.rewind

    puts(
      io
        .read
        .to_s
        .gsub(/(mayu-id='?)(\d+)/) { "#{$~[1]}\e[1;34m#{$~[2]}\e[0m" }
        .gsub(/(mayu-key='?)(\d+)/) { "#{$~[1]}\e[1;35m#{$~[2]}\e[0m" }
        .gsub(/>(.*?)</) { ">\e[33m#{$~[1]}\e[0m<" }
    )
  end

  def extract_numbers(source)
    REXML::Document.new(source).get_elements("//li").map(&:text).map(&:to_i)
  end
end
