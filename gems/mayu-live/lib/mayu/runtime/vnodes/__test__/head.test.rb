#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::HeadTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

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

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

      refute_nil(patches)
      assert_equal(1, document.head.size)

      instance.disable!
      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      unwrap_commands(batch)

      assert_equal(0, document.head.size)
    end
  end

  def test_head_render_without_start
    descriptor = H[:body, H[:head, H[:title, "Static"]], H[:main, "content"]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

    html = render_html(engine.root)

    assert_match("<title>Static</title>", html)
  end

  def test_flushing_the_head_leaves_it_clean
    descriptor = H[:body, H[:head, H[:title, "Static"]], H[:main, "content"]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    collector = Mayu::Runtime::VNodes::CommandCollector.new

    engine.root.replace_route_assets(stylesheets: ["/new.css"], scripts: [])
    assert(engine.head_dirty?)

    engine.flush_head(collector)

    # The walk re-registers the head node. That must not dirty the head again,
    # or every following batch would re-walk the whole document.
    refute(engine.head_dirty?)
  end

  class TitleProbe < Mayu::Component::Base
    def render
      [H[:head, H[:title, @__props[:title]]], H[:main, "content"]]
    end
  end

  def test_rerendering_a_head_with_the_same_content_does_not_dirty_it
    engine = Mayu::Runtime::Engine.new(H[:body, H[TitleProbe, title: "Same"]], metrics: NullMetrics.new)
    collector = Mayu::Runtime::VNodes::CommandCollector.new
    engine.flush_head(collector)
    refute(engine.head_dirty?)

    engine.update(H[:body, H[TitleProbe, title: "Same"]])

    refute(engine.head_dirty?)
  end

  def test_changing_head_content_dirties_it_and_renders_the_change
    engine = Mayu::Runtime::Engine.new(H[:body, H[TitleProbe, title: "Same"]], metrics: NullMetrics.new)
    collector = Mayu::Runtime::VNodes::CommandCollector.new
    engine.flush_head(collector)

    engine.update(H[:body, H[TitleProbe, title: "Other"]])

    assert(engine.head_dirty?)
    engine.flush_head(collector)
    refute(engine.head_dirty?)
    assert_match("<title>Other</title>", render_html(engine.root))
  end

  def test_route_stylesheets_are_rendered_without_component_discovery
    engine =
      Mayu::Runtime::Engine.new(
        H[:body, H[:main, "content"]],
        metrics: NullMetrics.new,
        stylesheets: ["/.mayu/assets/routes/home.css"],
        scripts: ["/.mayu/assets/routes/home.js"]
      )

    html = render_html(engine.root)

    assert_match(
      '<link rel="stylesheet" href="/.mayu/assets/routes/home.css">',
      html
    )
    assert_match(
      '<script type="module" src="/.mayu/assets/routes/home.js"></script>',
      html
    )
  end

  def test_stylesheets_precede_the_deferred_runtime_script
    engine =
      Mayu::Runtime::Engine.new(
        H[
          :body,
          H[:head, H[:title, "Example"], H[:meta, name: "viewport", content: "width=device-width"]],
          H[:main, "content"]
        ],
        metrics: NullMetrics.new,
        runtime_js: "/.mayu/init.js#session",
        stylesheets: ["/.mayu/assets/routes/home.css"]
      )

    html = render_html(engine.root)
    stylesheet = '<link rel="stylesheet" href="/.mayu/assets/routes/home.css">'
    runtime = '<script type="module" src="/.mayu/init.js#session"></script>'

    assert_operator(html.index("<title>Example</title>"), :<, html.index(stylesheet))
    assert_operator(html.index('name="viewport"'), :<, html.index(stylesheet))
    assert_operator(html.index(stylesheet), :<, html.index(runtime))
    refute_includes(html, "async=")
  end

  def test_head_updates_with_multiple_titles
    descriptor = H[:body, H[HeadToggleProbe]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

    html = render_html(engine.root)
    assert_equal(1, html.scan("<title>").length)
    assert_match("<title>B</title>", html)

    run_engine(descriptor) do |engine|
      component = find_component(engine.root, HeadToggleProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.set_mode(:b)

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      patches = unwrap_commands(batch)

      refute_nil(patches)
      refute_empty(patches)

      html = render_html(engine.root)
      assert_equal(1, html.scan("<title>").length)
      assert_match("<title>C</title>", html)
    end
  end

  def test_custom_element_inline_registration_script
    custom = Mayu::Runtime::Descriptors::CustomElement["my-element", "my-element.js"]
    descriptor = H[:body, H[custom, H[:span, "Hello"]]]

    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

    html = render_html(engine.root)

    assert_match('<script type="module"', html)
    assert_match('import("/.mayu/assets/my-element.js")', html)
    refute_match("customElements.define", html)
  end
end
