# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tmpdir"

require_relative "../build"

class Mayu::Build::UpdateEventTest < Minitest::Test
  Update = Data.define(:event, :errors) do
    def success? = errors.empty?

    def each_error(&) = errors.each(&)
  end

  def test_hash_is_serializable_and_relative_to_the_source_dir
    Dir.mktmpdir do |root|
      result = Klenod::Build::InvalidationResult.new([], [], ["app:/Card.haml"], [], [], [], [], [], [])
      event = Klenod::Build::UpdateEvent.new(["#{root}/Card.haml"], [], 4, result)

      update_event =
        Mayu::Build::UpdateEvent.new(update: Update.new(event, []), duration: 0.0052, source_dir: root)

      hash = JSON.parse(JSON.generate(update_event.to_hash))

      assert_equal("mayu.update", hash["type"])
      assert_equal(4, hash["version"])
      assert_equal("completed", hash["status"])
      assert_equal(["Card.haml"], hash["changed"])
      assert_equal(["app:/Card.haml"], hash["reloaded"])
      assert_equal([], hash["errors"])
    end
  end

  def test_failed_update_carries_error_reports
    Dir.mktmpdir do |root|
      event = Klenod::Build::UpdateEvent.new([], [], 5, nil)
      error = RuntimeError.new("boom")
      error.set_backtrace([])

      update_event =
        Mayu::Build::UpdateEvent.new(
          update: Update.new(event, [["app:/x.rb", error]]),
          duration: 0.001,
          source_dir: root
        )

      assert_equal(:failed, update_event.status)
      report = update_event.to_hash[:errors].first
      assert_equal("RuntimeError", report[:type])
      assert_equal("boom", report[:detail])
      assert_equal("app:/x.rb", report[:file])
    end
  end
end
