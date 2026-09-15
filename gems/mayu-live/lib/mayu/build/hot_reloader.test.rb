# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "stringio"

require_relative "../build"
require_relative "../component"
require_relative "../runtime/vnodes/vcomponent"

class Mayu::Build::HotReloaderTest < Minitest::Test
  # Collects the updates the reloader would hand to the server's App.
  class FakeApp
    attr_reader :updates

    def initialize
      @updates = Async::Queue.new
    end

    def notify_hmr_update(update)
      @updates.enqueue(update)
    end
  end

  class ReloadErrorProvider
    attr_reader :rewritten_error

    def initialize(sources: {})
      @sources = sources
    end

    def rewrite_exception(error)
      @rewritten_error = error
      error.set_backtrace(["app:/broken.haml:2"])
    end

    def absolute_path(module_id)
      @sources[module_id.to_s]
    end
  end

  # Stands in for a plugin's parse error. Klenod reports every source file it
  # cannot compile as a SourceError subclass that fills in the location.
  class FakeParseError < ::Klenod::Build::SourceError
    def kind = "Haml parse error"

    private

    def location(error)
      Location.new(
        line: 2,
        column: 4,
        detail: error.message,
        hints: ["Close the parenthesis"]
      )
    end
  end

  FakeDependency = Struct.new(:loc, :importer_id, :specifier)

  AppliedUpdate =
    Data.define(:errors) do
      def success? = errors.empty?

      def each_error(&) = errors.each(&)
    end

  def test_applies_an_update_and_notifies_the_app
    Dir.mktmpdir("mayu-klenod") do |root|
      app_dir = File.join(root, "app")
      FileUtils.mkdir_p(app_dir)
      css_path = File.join(app_dir, "root.css")
      File.write(File.join(app_dir, "root.haml"), "%p Before\n")

      provider = Mayu::Build::Configuration.new(root:).development_provider
      app = FakeApp.new

      Async do
        task = reloader(provider, app_dir).start(app)
        File.write(css_path, "p { color: red; }\n")
        publish_update(provider, css_path, graph_version: 1)

        update = app.updates.dequeue(timeout: 2)

        assert(update.success?)
        refute_empty(Dir.glob(File.join(root, ".assets", "*.css")))
      ensure
        task&.stop
      end.wait
    end
  end

  def test_recovers_after_a_failed_update
    Dir.mktmpdir("mayu-klenod") do |root|
      app_dir = File.join(root, "app")
      FileUtils.mkdir_p(app_dir)
      root_path = File.join(app_dir, "root.haml")
      File.write(root_path, "%p Before\n")

      provider = Mayu::Build::Configuration.new(root:).development_provider
      app = FakeApp.new

      Async do
        task = reloader(provider, app_dir).start(app)

        File.write(root_path, "= @columns.map do |column| }\n  %p= column\n")
        publish_update(provider, root_path, graph_version: 1)
        failed = app.updates.dequeue(timeout: 2)

        refute(failed.success?)
        assert_equal(["Haml parse error"], failed.errors.map(&:type))
        assert_equal("app:/root.haml", failed.errors.first.file)

        File.write(root_path, "%p After\n")
        publish_update(provider, root_path, graph_version: 2)
        recovered = app.updates.dequeue(timeout: 2)

        assert(recovered.success?)
        assert_includes(
          provider.context.entry("root.haml").record.transformed_source,
          "After"
        )
      ensure
        task&.stop
      end.wait
    end
  end

  def test_removes_deleted_assets
    Dir.mktmpdir("mayu-klenod") do |root|
      app_dir = File.join(root, "app")
      FileUtils.mkdir_p(app_dir)
      css_path = File.join(app_dir, "root.css")
      File.write(File.join(app_dir, "root.haml"), "%p Before\n")

      provider = Mayu::Build::Configuration.new(root:).development_provider
      app = FakeApp.new

      Async do
        task = reloader(provider, app_dir).start(app)
        File.write(css_path, "p { color: red; }\n")
        publish_update(provider, css_path, graph_version: 1)
        assert(app.updates.dequeue(timeout: 2).success?)
        refute_empty(Dir.glob(File.join(root, ".assets", "*.css")))

        File.delete(css_path)
        result =
          provider.context.invalidate_paths([], removed_paths: [css_path])
        provider.context.emit_update(
          ::Klenod::Build::UpdateEvent.new([], [css_path], 2, result)
        )
        update = app.updates.dequeue(timeout: 2)

        assert(update.success?)
        assert_empty(Dir.glob(File.join(root, ".assets", "*.css")))
      ensure
        task&.stop
      end.wait
    end
  end

  def test_updates_added_and_removed_routes
    Dir.mktmpdir("mayu-klenod") do |root|
      app_dir = File.join(root, "app")
      pages_dir = File.join(app_dir, "pages")
      route_dir = File.join(pages_dir, "about")
      route_path = File.join(route_dir, "+page.haml")
      FileUtils.mkdir_p(pages_dir)
      File.write(File.join(app_dir, "root.haml"), "%slot\n")
      File.write(File.join(pages_dir, "+page.haml"), "%p Home\n")

      provider = Mayu::Build::Configuration.new(root:).development_provider
      router = Mayu::Klenod::Router.new(provider)
      assert_nil(router.resolve("/about"))
      app = FakeApp.new

      Async do
        task = reloader(provider, app_dir).start(app)

        FileUtils.mkdir_p(route_dir)
        File.write(route_path, "%p About\n")
        publish_update(provider, route_path, graph_version: 1)
        added = app.updates.dequeue(timeout: 2)

        assert(added.success?)
        assert_equal(200, router.resolve("/about").status)

        File.delete(route_path)
        result =
          provider.context.invalidate_paths([], removed_paths: [route_path])
        provider.context.emit_update(
          ::Klenod::Build::UpdateEvent.new([], [route_path], 2, result)
        )
        removed = app.updates.dequeue(timeout: 2)

        assert(removed.success?)
        assert_nil(router.resolve("/about"))
      ensure
        task&.stop
      end.wait
    end
  end

  def test_reports_a_parse_error_with_its_source_location
    provider = ReloadErrorProvider.new
    error =
      FakeParseError.new(
        SyntaxError.new("unexpected token"),
        source: "%p\n%p= )\n",
        module_id: "app:/broken.haml"
      )

    update =
      reloader(provider, "/tmp").to_update(
        AppliedUpdate.new([["app:/broken.haml", error]])
      )

    refute(update.success?)
    report = update.errors.first
    assert_equal("app:/broken.haml", report.file)
    assert_equal("Haml parse error", report.type)
    assert_equal("unexpected token", report.detail)
    assert_equal("%p\n%p= )\n", report.source)
    assert_equal(2, report.line)
    assert_equal(4, report.column)
    assert_equal(["Close the parenthesis"], report.hints)
    # A build error's backtrace runs through the build graph rather than the
    # app, so it is dropped.
    assert_empty(report.backtrace)
    assert_same(error, provider.rewritten_error)
  end

  def test_reports_the_import_site_of_a_resolve_failure
    Dir.mktmpdir do |dir|
      source = "import a from \"./a\";\nimport colors from \"./colors.toml\";\n"
      path = Pathname(dir).join("CustomElement.tsx")
      path.write(source)
      provider =
        ReloadErrorProvider.new(sources: {"app:/CustomElement.tsx" => path})

      error =
        ::Klenod::Build::ResolveError.new(
          nil,
          dependency:
            FakeDependency.new(
              loc:
                ::Klenod::Build::SourceLocation.new(
                  "app:/CustomElement.tsx",
                  2,
                  21
                ),
              importer_id: "app:/CustomElement.tsx",
              specifier: "./colors.toml"
            ),
          importer_id: "app:/CustomElement.tsx",
          reason: :not_found,
          requested_specifier: "./colors.toml",
          suggestions: ["./colors.json"]
        )

      update =
        reloader(provider, dir).to_update(
          AppliedUpdate.new([["app:/CustomElement.tsx", error]])
        )

      report = update.errors.first
      assert_equal("app:/CustomElement.tsx", report.file)
      assert_equal("Module not found", report.type)
      assert_equal("Could not resolve \"./colors.toml\"", report.detail)
      assert_equal(2, report.line)
      assert_equal(21, report.column)
      assert_equal(["Did you mean ./colors.json?"], report.hints)
      # ResolveError names the importing module but does not carry its source.
      assert_equal(source, report.source)
      assert_empty(report.backtrace)
    end
  end

  def test_keeps_the_backtrace_for_unknown_errors
    provider = ReloadErrorProvider.new
    error = RuntimeError.new("something unexpected")
    error.set_backtrace(["generated:/broken.rb:20"])

    update =
      reloader(provider, "/tmp").to_update(
        AppliedUpdate.new([["app:/broken.haml", error]])
      )

    report = update.errors.first
    assert_equal("RuntimeError", report.type)
    assert_equal("something unexpected", report.detail)
    assert_equal(["app:/broken.haml:2"], report.backtrace)
    assert_nil(report.line)
  end

  private

  def reloader(provider, source_dir)
    Mayu::Build::HotReloader.new(
      provider:,
      source_dir:,
      logger:
        Mayu::Build::UpdateLogger.new(
          source_dir:,
          provider:,
          output: StringIO.new,
          error_output: StringIO.new
        )
    )
  end

  def publish_update(provider, path, graph_version:)
    result = provider.context.invalidate_paths([path])
    provider.context.emit_update(
      ::Klenod::Build::UpdateEvent.new([path], [], graph_version, result)
    )
  end
end
