#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "stringio"
require "console/output/terminal"

require_relative "render_error_event"

class Mayu::Runtime::RenderErrorEventTest < Minitest::Test
  class Provider
    def source_excerpts(_error, context: 2)
      [
        {
          file: "/app/app/pages/+page.haml",
          excerpts: [
            [
              {line: 2, text: "%p hello", highlight: false},
              {line: 3, text: "= raise", highlight: true}
            ]
          ]
        }
      ]
    end
  end

  class Page
    def self.to_s = "app/pages/+page.haml"
  end

  def test_lists_app_frames_counts_the_rest_and_shows_the_source
    output = StringIO.new
    Console::Logger.new(Console::Output::Text.new(output)).error("page", event: event)
    text = output.string

    assert_includes(text, "RuntimeError: boom")
    assert_includes(text, "app/pages/+page.haml:3:in 'render'")
    assert_includes(text, "2 more frames through Mayu")
    refute_includes(text, "vendor/bundle")
    refute_includes(text, "vcomponent.rb")
    assert_includes(text, "    2: %p hello")
    assert_includes(text, ">   3: = raise")
    refute_includes(text, "\e[")
  end

  def test_hash_is_serializable
    hash = JSON.parse(JSON.generate(event.to_hash))

    assert_equal("mayu.render_error", hash["type"])
    assert_equal("app/pages/+page.haml", hash["component"])
    assert_equal("RuntimeError", hash["error"])
    assert_equal(2, hash["hidden_frames"])
    assert_equal(1, hash["backtrace"].length)
  end

  private

  def event
    error = RuntimeError.new("boom")
    error.set_backtrace(
      [
        "/app/app/pages/+page.haml:3:in 'render'",
        "/app/vendor/bundle/ruby/4.0.0/gems/async-2.45.1/lib/async/task.rb:9:in 'run'",
        "/app/gems/mayu-live/lib/mayu/runtime/vnodes/vcomponent.rb:1:in 'update'"
      ]
    )

    Mayu::Runtime::RenderErrorEvent.for(
      error,
      component: Page.new,
      provider: Provider.new,
      root: "/app"
    )
  end
end
