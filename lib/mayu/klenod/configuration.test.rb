# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

require_relative "../klenod"
require_relative "../component"
require_relative "../runtime/vnodes/vcomponent"

class Mayu::Klenod::ConfigurationTest < Minitest::Test
  def test_development_and_runtime_providers_share_the_same_entry_exports
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "entry.rb"), "VALUE = 42\n")

      configuration =
        Mayu::Klenod::Configuration.new(
          root:,
          entrypoints: ["entry"],
          output: ".mayu/app.bundle"
        )

      development = configuration.development_provider
      assert_equal(42, development.exports(development.entry("entry"))::VALUE)
      assert_equal("app:/entry.rb", development.module_id_for("entry").to_s)

      configuration.build
      runtime = configuration.runtime_provider

      assert_equal(42, runtime.exports("entry")::VALUE)
      assert_equal(42, runtime.exports(runtime.entry("entry"))::VALUE)
      assert_equal("app:/entry.rb", runtime.module_id_for("entry"))
      assert_equal("/.mayu/assets/", runtime.asset_base)
    end
  end

  def test_development_context_uses_mayus_module_namespace
    configuration = Mayu::Klenod::Configuration.new(root: Dir.pwd)

    assert_same(Mayu::ModuleNamespace, configuration.context.graph.namespace)
  end

  def test_default_context_includes_the_klenod_test_plugin
    configuration = Mayu::Klenod::Configuration.new(root: Dir.pwd)

    assert(
      configuration.context.graph.plugins.any? do |plugin|
        plugin.is_a?(Klenod::Test::Plugin)
      end
    )
  end

  def test_build_accepts_an_explicit_output_path
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "entry.rb"), "VALUE = 42\n")

      configuration =
        Mayu::Klenod::Configuration.new(root:, entrypoints: ["entry"])
      output = File.join(root, "build", "app.mayu-bundle")

      configuration.build(output:)

      assert_path_exists(output)
      assert_equal(
        42,
        configuration.runtime_provider(bundle_path: output).exports(
          "entry"
        )::VALUE
      )
    end
  end

  def test_klenod_config_file_is_evaluated_against_mayu_defaults
    Dir.mktmpdir("mayu-klenod") do |root|
      File.write(File.join(root, "klenod.config.rb"), <<~RUBY)
        source_dir "frontend"
        pages_dir "routes"
        entrypoints "entry", "virtual:router"
        base "/assets/"
      RUBY

      configuration = Mayu::Klenod::Configuration.load(root:)

      assert_equal("frontend", configuration.source_dir)
      assert_equal("routes", configuration.pages_dir)
      assert_equal(
        %w[root.haml virtual:router entry virtual:router],
        configuration.entrypoints
      )
      assert_equal("/assets/", configuration.base)
    end
  end

  def test_pages_dir_configures_the_router_plugin_used_by_the_provider
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "frontend", "routes"))
      File.write(File.join(root, "klenod.config.rb"), <<~RUBY)
        source_dir "frontend"
        pages_dir "routes"
      RUBY
      File.write(File.join(root, "frontend", "root.haml"), "%slot\n")
      File.write(
        File.join(root, "frontend", "routes", "+page.haml"),
        "%p Configured route\n"
      )

      provider = Mayu::Klenod::Configuration.load(root:).development_provider
      resolved = Mayu::Klenod::Router.new(provider).resolve("/")

      refute_nil(resolved)
      assert_equal(200, resolved.status)
      assert_equal("app:/routes/+page.haml", resolved.module_ids.last)
    end
  end

  def test_default_haml_plugin_maps_props_context_and_state_to_mayu_receivers
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "card.haml"), <<~'HAML')
        :ruby
          def initialize
            @count = 1
            @@section = "profile"
          end

        %p= "#{$title}:#{@@section}:#{@count}"
      HAML

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      component_class = provider.exports(provider.entry("card.haml"))::Default
      component = component_class.allocate
      component.instance_variable_set(:@__props, {title: "Ada"}.freeze)
      component.instance_variable_set(
        :@__context,
        Mayu::Runtime::VNodes::VComponent::Context.new
      )
      component.instance_variable_set(
        :@__state,
        Mayu::Component::State.new(component)
      )
      component.send(:initialize)

      descriptor = component.render

      assert_equal(:p, descriptor.type)
      assert_equal(["Ada:profile:1"], descriptor.children.descriptors)
    end
  end

  def test_default_markdown_plugin_uses_mayu_components_and_the_component_map
    Dir.mktmpdir("mayu-klenod") do |root|
      app = File.join(root, "app")
      FileUtils.mkdir_p(app)
      File.write(
        File.join(app, "markdown-components.rb"),
        <<~RUBY
          class Heading < Mayu::Component::Base
          end

          Default = {h1: Heading}.freeze
        RUBY
      )
      File.write(File.join(app, "page.md"), "# Imported heading\n")
      File.write(File.join(app, "page.haml"), ":markdown\n  # Inline heading\n")

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      map = provider.exports(provider.entry("markdown-components.rb"))::Default
      markdown = provider.exports(provider.entry("page.md"))::Default
      inline = provider.exports(provider.entry("page.haml"))::Default

      assert_equal(Mayu::Component::Base, markdown.superclass)
      assert_equal(map.fetch(:h1), markdown.allocate.render.type)
      assert_equal({id: "imported-heading"}, markdown.allocate.render.props)
      assert_equal(map.fetch(:h1), inline.allocate.render.type)
      assert_equal({id: "inline-heading"}, inline.allocate.render.props)
      assert_equal(
        ["/markdown-components"],
        provider.entry("page.haml").record.dependencies.filter_map do |dependency|
          dependency.specifier if dependency.kind == :markdown_components
        end
      )
    end
  end

  def test_default_haml_plugin_uses_klenod_class_names_for_companion_css
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "card.haml"), "%p.title Card\n")
      File.write(File.join(root, "app", "card.css"), ".title { color: red; }\n")

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      component_class = provider.exports(provider.entry("card.haml"))::Default
      descriptor = component_class.allocate.render

      assert_equal(
        component_class::ClassNames[:title],
        descriptor.props[:class]
      )
      refute_empty(descriptor.props[:class])
    end
  end

  def test_default_haml_plugin_merges_scoped_classes_with_component_props
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "button.haml"), "%button{ **$* } Button\n")
      File.write(File.join(root, "app", "button.css"), "button { color: red; }\n")

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      component_class = provider.exports(provider.entry("button.haml"))::Default
      component = component_class.allocate
      component.instance_variable_set(:@__props, {class: "caller", "data-id": "example"}.freeze)
      descriptor = component.render

      assert_equal(
        [component_class::ClassNames[:__button], "caller"].join(" "),
        descriptor.props.fetch(:class)
      )
      assert_equal("example", descriptor.props.fetch(:data_id))
    end
  end

  def test_default_haml_plugin_renders_imports_and_slots
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "label.haml"), "%strong Label\n")
      File.write(File.join(root, "app", "card.haml"), <<~HAML)
        :ruby
          Label = import("./label")

        %section
          %Label
          %slot
      HAML

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      component_class = provider.exports(provider.entry("card.haml"))::Default
      label_class = provider.exports(provider.entry("label.haml"))::Default
      component = component_class.allocate
      component.instance_variable_set(
        :@__children,
        Mayu::Runtime::Descriptors::Children[[Mayu::Runtime::H[:em, "Slotted"]]]
      )
      descriptor = component.render

      assert_equal(:section, descriptor.type)
      assert_equal(2, descriptor.children.descriptors.length)
      assert_equal(label_class, descriptor.children.descriptors.first.type)
      slotted = descriptor.children.descriptors.last.fetch(0)
      assert_equal(:em, slotted.type)
      assert_equal(["Slotted"], slotted.children.descriptors)
    end
  end

  def test_default_haml_plugin_renders_named_string_slots
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "layout.haml"), <<~HAML)
        %aside
          %slot(name="menu")
      HAML

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      component_class = provider.exports(provider.entry("layout.haml"))::Default
      component = component_class.allocate
      component.instance_variable_set(
        :@__children,
        Mayu::Runtime::Descriptors::Children[
          [Mayu::Runtime::H[:nav, "Menu", slot: "menu"]]
        ]
      )
      descriptor = component.render
      menu = descriptor.children.descriptors.fetch(0).fetch(0)

      assert_equal(:nav, menu.type)
      assert_equal(["Menu"], menu.children.descriptors)
    end
  end

  def test_klenod_provider_formats_haml_render_errors_with_original_source
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "broken.haml"), <<~HAML)
        :ruby
          def explode
            raise "boom"
          end

        %p= explode
      HAML

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      component_class = provider.exports(provider.entry("broken.haml"))::Default

      error = assert_raises(RuntimeError) { component_class.allocate.render }
      formatted =
        provider.format_exception(error, source_path: "app:/broken.haml")

      assert_includes(formatted, "broken.haml")
      assert_includes(formatted, 'raise "boom"')
    end
  end

  def test_default_haml_plugin_preserves_text_whitespace_and_event_callbacks
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "button.haml"), <<~HAML)
        :ruby
          def handle_click
          end

        %button(onclick=handle_click){ style: { color: "red" } }
          Hello world
      HAML

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      component_class = provider.exports(provider.entry("button.haml"))::Default
      component = component_class.allocate
      descriptor = component.render
      callback = descriptor.props.fetch(:onclick)

      assert_equal(["Hello world"], descriptor.children.descriptors)
      assert_instance_of(Mayu::Runtime::Descriptors::Callback, callback)
      assert_same(component, callback.component)
      assert_equal(:handle_click, callback.method_name)
      assert_equal({color: "red"}, descriptor.props.fetch(:style))
    end
  end

  def test_default_image_plugin_generates_klenod_inline_placeholders
    configuration = Mayu::Klenod::Configuration.new(root: Dir.pwd)
    plugin =
      configuration.plugins.find do |candidate|
        candidate.is_a?(::Klenod::Build::Plugins::ImagePlugin::Plugin)
      end
    placeholder = plugin.instance_variable_get(:@placeholder)

    assert_equal(16, placeholder.width)
    assert_equal("webp", placeholder.format)
    assert_equal(80, placeholder.quality)
  end

  def test_default_plugins_include_google_fonts_with_a_project_cache
    root = File.expand_path("../../..", __dir__)
    configuration = Mayu::Klenod::Configuration.new(root:)
    plugin =
      configuration.plugins.find do |candidate|
        candidate.is_a?(::Klenod::Build::Plugins::GoogleFontsPlugin::Plugin)
      end

    refute_nil(plugin)
    assert_equal(
      File.join(root, ".mayu", "google_fonts"),
      plugin.instance_variable_get(:@css_cache).instance_variable_get(:@path)
    )
  end

  def test_default_router_config_uses_mayu_route_as_the_handler_base_class
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app", "pages", "api"))
      File.write(
        File.join(root, "app", "pages", "api", "+route.rb"),
        "def GET(request) = request.path\n"
      )

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      router = provider.exports(provider.entry("virtual:router"))::Default
      handler = router.match("/api").handler

      assert_operator(handler, :<, Mayu::Route)
      assert_equal(
        "/api",
        handler.new.GET(
          Mayu::Route::Request.new("GET", "/api", {}, nil, {}, {})
        )
      )
    end
  end

  def test_example_includes_a_klenod_route_handler
    provider =
      Mayu::Klenod::Configuration.new(
        root: File.expand_path("../../../example", __dir__)
      ).development_provider
    router = provider.exports(provider.entry("virtual:router"))::Default
    handler = router.match("/api/health").handler

    status, headers, body =
      handler.new.GET(
        Mayu::Route::Request.new("GET", "/api/health", {}, nil, {}, {})
      )

    assert_equal(200, status)
    assert_equal({"content-type" => "application/json"}, headers)
    assert_equal('{"status":"ok"}', body)
  end
end
