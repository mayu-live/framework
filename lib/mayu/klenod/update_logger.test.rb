# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"

require_relative "../klenod"

class Mayu::Klenod::UpdateLoggerTest < Minitest::Test
  Update = Data.define(:event, :errors) do
    def success? = errors.empty?

    def each_error(&) = errors.each(&)
  end

  def test_logs_changed_files_and_reloaded_components
    Dir.mktmpdir do |root|
      output = StringIO.new
      logger = Mayu::Klenod::UpdateLogger.new(source_dir: root, output:, env: {"NO_COLOR" => "1"})
      result = result(reloaded: ["app:/components/Card.haml"], reevaluated: ["virtual:/router.rb"])
      event = Klenod::Build::UpdateEvent.new(["#{root}/components/Card.haml"], [], 4, result)

      logger.log(update: Update.new(event, []), duration: "1.0000ms")

      assert_includes(output.string, "Update #4 completed")
      assert_includes(output.string, "changed files:")
      assert_includes(output.string, "components/Card.haml")
      assert_includes(output.string, "reloaded:")
      assert_includes(output.string, "app:/components/Card.haml")
      assert_includes(output.string, "reevaluated:")
      assert_includes(output.string, "virtual:/router.rb")
    end
  end

  def test_logs_a_source_error_without_a_backtrace
    Dir.mktmpdir do |root|
      output = StringIO.new
      logger =
        Mayu::Klenod::UpdateLogger.new(
          source_dir: root,
          output:,
          error_output: output,
          env: {"NO_COLOR" => "1"}
        )
      event = Klenod::Build::UpdateEvent.new([], [], 7, result)
      error =
        ParseError.new(
          RuntimeError.new("Invalid tag"),
          source: "%article\n  %@$O\n  %p\n",
          module_id: "app:/broken.haml"
        )

      logger.log(
        update: Update.new(event, [["app:/broken.haml", error]]),
        duration: "1.0000ms"
      )

      assert_includes(output.string, "Update #7 failed")
      assert_includes(output.string, "app:/broken.haml:2:3: Haml parse error")
      assert_includes(output.string, "Invalid tag")
      assert_includes(output.string, "> 2 |   %@$O")
      assert_includes(output.string, "Close the tag")
      refute_includes(output.string, "vendor/bundle")
    end
  end

  def test_logs_an_unknown_error_with_its_backtrace
    Dir.mktmpdir do |root|
      output = StringIO.new
      logger =
        Mayu::Klenod::UpdateLogger.new(
          source_dir: root,
          output:,
          error_output: output,
          env: {"NO_COLOR" => "1"}
        )
      event = Klenod::Build::UpdateEvent.new([], [], 8, result)
      error = RuntimeError.new("something unexpected")
      error.set_backtrace(
        [
          "app:/x.rb:3:in 'foo'",
          "/app/vendor/bundle/ruby/4.0.0/gems/klenod-build-0.0.13/lib/graph.rb:1:in 'load'",
          "/app/vendor/bundle/ruby/4.0.0/gems/async-2.45.1/lib/task.rb:9:in 'run'"
        ]
      )

      logger.log(
        update: Update.new(event, [["app:/x.rb", error]]),
        duration: "1.0000ms"
      )

      assert_includes(output.string, "something unexpected")
      assert_includes(output.string, "Backtrace:")
      assert_includes(output.string, "app:/x.rb:3:in 'foo'")
      # Frames through the build graph are summarized, not listed.
      refute_includes(output.string, "klenod-build")
      assert_includes(output.string, "2 more frames through the build")
    end
  end

  def test_omits_the_excerpt_when_the_line_cannot_be_trusted
    Dir.mktmpdir do |root|
      output = StringIO.new
      # A module that failed to load loses its source map, so its backtrace
      # still points at generated Ruby rather than the original source.
      provider =
        Class.new do
          def source_mapped?(_module_id) = false

          def absolute_path(_module_id) = raise("should not be read")
        end.new
      logger =
        Mayu::Klenod::UpdateLogger.new(
          source_dir: root,
          output:,
          error_output: output,
          env: {"NO_COLOR" => "1"},
          provider:
        )
      event = Klenod::Build::UpdateEvent.new([], [], 9, result)
      error = NameError.new("uninitialized constant Foobar")
      error.set_backtrace(["/app/pages/+layout.haml:25:in '<class:Layout>'"])

      logger.log(
        update: Update.new(event, [["app:/pages/+layout.haml", error]]),
        duration: "1.0000ms"
      )

      assert_includes(output.string, "uninitialized constant Foobar")
      refute_includes(output.string, "Source:")
    end
  end

  private

  # Klenod reports every source file it cannot compile as a SourceError
  # subclass that fills in the location.
  class ParseError < Klenod::Build::SourceError
    def kind = "Haml parse error"

    private

    def location(error)
      Location.new(
        line: 2,
        column: 3,
        detail: error.message,
        hints: ["Close the tag"]
      )
    end
  end

  def result(reloaded: [], reevaluated: [])
    Klenod::Build::InvalidationResult.new([], [], reloaded, reevaluated, [], [], [], [], [])
  end
end
