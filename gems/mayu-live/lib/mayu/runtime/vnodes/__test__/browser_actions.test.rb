#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::BrowserActionsTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  class AlertProbe < Mayu::Component::Base
    def initialize
      @count = 0
    end

    def handle_alert
      @count += 1
      rerender!
      browser.alert("Count: #{@count}")
    end

    def render
      H[:span, @count.to_s]
    end
  end

  def test_browser_actions_follow_the_dom_updates_queued_before_them
    run_engine(H[:body, H[AlertProbe]]) do |engine|
      component = find_component(engine.root, AlertProbe)
      instance = component.instance_variable_get(:@instance)

      wait_until { instance.respond_to?(:rerender!) }

      instance.handle_alert

      batch = Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
      commands = batch.commands

      set_text =
        commands.index { it.is_a?(Mayu::Runtime::Commands::SetTextContent) }
      action =
        commands.index { it.is_a?(Mayu::Runtime::Commands::BrowserAction) }

      refute_nil(set_text)
      refute_nil(action)
      assert_operator(set_text, :<, action)
      assert_equal("alert", commands[action].name)
      assert_equal(["Count: 1"], commands[action].args)
    end
  end
end
