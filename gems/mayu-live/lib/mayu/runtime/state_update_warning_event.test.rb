#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "console"
require "console/output/terminal"

require_relative "state_update_warning_event"

class Mayu::Runtime::StateUpdateWarningEventTest < Minitest::Test
  class Provider
    def rewrite_exception(error)
      error.set_backtrace(["app:/pages/demos/silent-haml/+page.haml:12:in 'render'"])
    end

    def source_location(_error)
      {
        file: "app:/pages/demos/silent-haml/+page.haml",
        line: 12
      }
    end

    def source_excerpts(_error)
      [
        {
          file: "app:/pages/demos/silent-haml/+page.haml",
          excerpts: [
            [
              {line: 11, text: "  @setup_runs = 0", highlight: false},
              {line: 12, text: "- @setup_runs += 1", highlight: true}
            ]
          ]
        }
      ]
    end
  end

  class Page
    def self.module_path = "/project/app/pages/demos/silent-haml/+page.haml"
  end

  def test_rewrites_the_location_and_shows_the_source_excerpt
    output = StringIO.new
    Console::Logger.new(Console::Output::Text.new(output)).warn(Page.new, event: event)

    assert_includes(
      output.string,
      "State update during render at app:/pages/demos/silent-haml/+page.haml:12"
    )
    assert_includes(output.string, "    11:   @setup_runs = 0")
    assert_includes(output.string, ">  12: - @setup_runs += 1")
  end

  def test_colours_the_warning_on_a_terminal
    output = StringIO.new
    output.define_singleton_method(:winsize) { [24, 120] }
    terminal = Console::Output::Terminal.new(output, format: Console::Terminal::XTerm)
    Console::Logger.new(terminal).warn(Page.new, event: event)

    assert_match(/\e\[[\d;]*m?State update during render/, output.string)
    assert_match(/\e\[[\d;]*m?app:\/pages/, output.string)
  end

  def test_uses_the_component_module_id_without_an_incorrect_generated_line
    event =
      Mayu::Runtime::StateUpdateWarningEvent.for(
        Page.new,
        path: "/project/app/pages/demos/silent-haml/+page.haml",
        line: 40
      )

    assert_equal("app:/pages/demos/silent-haml/+page.haml", event.to_hash[:location])
    assert_empty(event.to_hash[:sources])
  end

  private

  def event
    Mayu::Runtime::StateUpdateWarningEvent.for(
      Page.new,
      path: "/app/app/pages/demos/silent-haml/+page.haml",
      line: 40,
      provider: Provider.new
    )
  end
end
