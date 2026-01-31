#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes2::HeadTest < Minitest::Test
  include Mayu::Runtime::VNodes2::TestHelpers

  class HeadProbe < Mayu::Component::Base
    def initialize
      @enabled = false
    end

    def enable!
      @enabled = true
      rerender!
    end

    def disable!
      @enabled = false
      rerender!
    end

    def render
      [(@enabled ? H[:head, H[:title, "Enabled"]] : nil), H[:main, "content"]]
    end
  end

  class HeadToggleProbe < Mayu::Component::Base
    def initialize
      @mode = :a
    end

    def set_mode(mode)
      @mode = mode
      rerender!
    end

    def render
      case @mode
      when :a
        [
          H[:head, H[:title, "A"]],
          H[:head, H[:title, "B"]],
          H[:main, "content"]
        ]
      when :b
        [H[:head, H[:title, "C"]], H[:main, "content"]]
      else
        [H[:main, "content"]]
      end
    end
  end

  class StylesProbe < Mayu::Component::Base
    def self.module_path = "/styles/probe"

    def render
      H[:div, "styles"]
    end
  end

  def test_head_nodes_register_and_unregister
    descriptor = H[:body, H[HeadProbe]]

    run_engine(descriptor) do |engine|
      document = engine.root
      component = find_component(document, HeadProbe)
      instance = component.instance_variable_get(:@instance)

      assert_equal(0, document.head.size)

      wait_until { instance.respond_to?(:rerender!) }

      instance.enable!

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      refute_nil(patches)
      assert_equal(1, document.head.size)

      instance.disable!
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      unwrap_patches(batch)

      assert_equal(0, document.head.size)
    end
  end

  def test_head_render_without_start
    descriptor = H[:body, H[:head, H[:title, "Static"]], H[:main, "content"]]
    engine =
      Mayu::Runtime::VNodes2::Engine.new(descriptor, metrics: NullMetrics.new)

    html = render_html(engine.root)

    assert_match("<title>Static</title>", html)
  end

  def test_head_updates_with_multiple_titles
    descriptor = H[:body, H[HeadToggleProbe]]
    engine =
      Mayu::Runtime::VNodes2::Engine.new(descriptor, metrics: NullMetrics.new)

    html = render_html(engine.root)
    assert_equal(1, html.scan("<title>").length)
    assert_match("<title>B</title>", html)

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, HeadToggleProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.set_mode(:b)

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_patches }
      patches = unwrap_patches(batch)

      refute_nil(patches)
      refute_empty(patches)

      html = render_html(engine.root)
      assert_equal(1, html.scan("<title>").length)
      assert_match("<title>C</title>", html)
    end
  end

  def test_component_stylesheet_registration
    mod = Data.define(:assets, :dependencies).new(["styles.css"], [])
    system =
      Data
        .define(:mod) do
          def get_mod(_path)
            mod
          end
        end
        .new(mod)

    key = Mayu::Modules::System::CURRENT_KEY
    previous = Thread.current.thread_variable_get(key)
    Thread.current.thread_variable_set(key, system)

    descriptor = H[:body, H[StylesProbe]]
    engine =
      Mayu::Runtime::VNodes2::Engine.new(descriptor, metrics: NullMetrics.new)

    html = render_html(engine.root)

    assert_match(
      '<link rel="stylesheet" href="/.mayu/assets/styles.css">',
      html
    )
  ensure
    Thread.current.thread_variable_set(key, previous)
  end
end
