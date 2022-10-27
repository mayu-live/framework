# typed: true
require_relative "../disable_sorbet"
# Mayu::DisableSorbet.disable_sorbet!

require "minitest/autorun"
require "test_helper"
require "async"
require "rexml/document"
require "stringio"
require "ruby-prof"
require_relative "vtree"
require_relative "h"
require_relative "../session"
require_relative "../commands"
require_relative "../app_metrics"

class PerfTest < Minitest::Test
  class MyComponent < Mayu::Component::Base
    include Mayu::VDOM::H

    def self.get_initial_state(**props)
      { page: 0 }
    end

    def handle_next_page(e)
      update { |state| { page: state[:page].succ } }
    end

    def render
      per_page = 150
      items = props[:items].slice(state[:page] * per_page, per_page)

      h(
        :div,
        (h(:button, on_click: handler(:handle_next_page)) unless items.empty?),
        h(:ul, items.map { h(:li, _1, key: _1) })
      )
    end
  end

  include Mayu::VDOM::H

  def test_perf
    items = 5000.times.map { SecureRandom.alphanumeric(5 + rand(10)) }

    Async do
      vtree = setup_vtree
      app = h(MyComponent, items:)
      vtree.render(app)
      vtree.to_html.tap { |html| print_xml(html) }

      result =
        RubyProf.profile do
          while handler_ref =
                  vtree.instance_variable_get(:@handlers).values.first
            handler_ref.call({})
            update_vtree(vtree)
          end
        end

      printer = RubyProf::GraphHtmlPrinter.new(result)

      File.open(File.join(__dir__, "profile.html"), "w") do |f|
        printer.print(f, min_percent: 0)
      end

      vtree.render(app)
      vtree.to_html.tap { |html| print_xml(html) }
    end
  end

  private

  def update_vtree(vtree)
    ctx = Mayu::VDOM::UpdateContext.new

    vtree.update_queue.size.times do
      case vtree.update_queue.dequeue
      in Mayu::VDOM::VNode => vnode
        next if vnode.removed?
        vtree.patch(ctx, vnode, vnode.descriptor, lifecycles: false)
      else
        # ok
      end
    end

    ctx
  end

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
