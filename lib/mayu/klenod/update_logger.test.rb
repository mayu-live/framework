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

  private

  def result(reloaded: [], reevaluated: [])
    Klenod::Build::InvalidationResult.new([], [], reloaded, reevaluated, [], [], [], [], [])
  end
end
