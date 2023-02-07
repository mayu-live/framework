# typed: false

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

class Mayu::VDOM::PerformanceTest < Minitest::Test
  H = Mayu::VDOM::H

  class Item < Mayu::Component::Base
    def render
      H[:li, H[:a, props[:children].to_a, href: props[:path]]]
    end
  end

  class MyComponent < Mayu::Component::Base
    def self.get_initial_state(**props)
      { page: 0 }
    end

    def handle_next_page(e)
      update { |state| { page: state[:page].succ } }
    end

    def render
      per_page = 50
      items = props[:items].slice(state[:page] * per_page, per_page)

      H[
        :div,
        (H[:button, on_click: handler(:handle_next_page)] unless items.empty?),
        H[:ul, items.map { H[Item, _1, key: _1, path: "/#{_1}"] }]
      ]
    end
  end

  def test_perf
    items = 2000.times.map { SecureRandom.alphanumeric(5 + rand(10)) }

    Async do
      vtree = setup_vtree
      app = H[MyComponent, items:]
      vtree.render(app)
      vtree.to_html.tap { |html| print_xml(html) }

      # https://ruby-prof.github.io/#measurements
      RubyProf.measure_mode = RubyProf::WALL_TIME
      # RubyProf.measure_mode = RubyProf::PROCESS_TIME
      # RubyProf.measure_mode = RubyProf::ALLOCATIONS
      # RubyProf.measure_mode = RubyProf::MEMORY

      profile = RubyProf::Profile.new(track_allocations: true)
      profile.exclude_methods!(T::Types::Union, :recursively_valid?)
      profile.exclude_methods!(T::Types::FixedArray, :initialize)
      profile.exclude_methods!(T::Props::WeakConstructor, :initialize)
      # profile.exclude_methods!(T::Props::Constructor::DecoratorMethods, :construct_props_without_defaults)
      profile.exclude_methods!(T::Types::TypedEnumerable, :recursively_valid?)
      # profile.exclude_methods!(T::Private::Methods::Signature, :initialize)

      result =
        profile.profile do
          while handler_ref =
                  vtree.instance_variable_get(:@handlers).values.first
            handler_ref.call({})
            update_vtree(vtree)
          end
        end

      printer = RubyProf::MultiPrinter.new(result)
      path = File.join(Mayu::TestHelper::ROOT, "profile")
      FileUtils.mkdir_p(path)
      printer.print(path:, profile: File.basename(__FILE__, ".*"))

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
      def load_root(path, headers: {})
        H[:div]
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
