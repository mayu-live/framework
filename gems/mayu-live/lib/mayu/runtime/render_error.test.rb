#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "console"

require_relative "render_error"

class Mayu::Runtime::RenderErrorTest < Minitest::Test
  class Provider
    def rewrite_exception(_error)
    end

    def module_id_for(path)
      raise KeyError, path unless path.start_with?("/app/app/")

      "app:" + path.delete_prefix("/app/app")
    end

    def source_location(_error)
      {file: "app:/pages/+page.haml", source: "%p hello\n= raise\n", line: 2}
    end
  end

  class Page
    def self.module_path = "/app/app/pages/+page.haml"
  end

  def setup
    Console.logger = Console::Logger.new(Console::Output::Null.new)
  end

  def teardown
    Console.logger = nil
  end

  def test_the_command_names_modules_and_carries_the_source_in_development
    command = report(with_source: true)

    assert_equal("app:/pages/+page.haml", command.file)
    assert_equal("RuntimeError", command.type)
    assert_equal("boom", command.message)
    assert_equal("%p hello\n= raise\n", command.source)
    assert_equal(2, command.line)
    assert_equal(
      [{name: "#document"}, {name: "body"}, {name: "Page", path: "app:/pages/+page.haml"}],
      command.tree_path
    )
  end

  def test_the_command_names_frames_by_module_id_and_gem_files_by_gem
    command = report(with_source: true)

    assert_equal(
      [
        "app:/pages/+page.haml:2:in 'render'",
        "async-2.45.1/lib/async/task.rb:9:in 'run'",
        "<internal:kernel>:187:in 'Kernel#loop'"
      ],
      command.backtrace
    )
  end

  def test_the_command_skips_the_source_outside_development
    command = report(with_source: false)

    assert_equal("app:/pages/+page.haml", command.file)
    assert_nil(command.source)
    assert_nil(command.line)
  end

  private

  def report(with_source:)
    error = RuntimeError.new("boom")
    error.set_backtrace(
      [
        "/app/app/pages/+page.haml:2:in 'render'",
        "/app/vendor/bundle/ruby/4.0.0/gems/async-2.45.1/lib/async/task.rb:9:in 'run'",
        "<internal:kernel>:187:in 'Kernel#loop'"
      ]
    )

    Mayu::Runtime::RenderError.report(
      error,
      component: Page.new,
      tree_path: [{name: "#document"}, {name: "body"}, {name: "Page", path: "/app/app/pages/+page.haml"}],
      provider: Provider.new,
      with_source:
    )
  end
end
