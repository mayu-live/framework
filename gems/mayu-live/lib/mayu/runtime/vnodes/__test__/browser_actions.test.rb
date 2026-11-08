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

  class ReloadProbe < Mayu::Component::Base
    def mount
      browser.reload_other_tabs
      browser.navigate("/done", replace: true, document: true)
    end

    def render = H[:p, "Complete"]
  end

  def test_mount_can_broadcast_before_navigating_the_sending_tab
    run_engine(H[ReloadProbe]) do |engine|
      actions = []
      Async::Task.current.with_timeout(0.5) do
        loop do
          actions.concat(engine.dequeue_batch.commands.grep(Mayu::Runtime::Commands::BrowserAction))
          break if actions.length == 2
        end
      end
      assert_equal(["reload_other_tabs", "navigate"], actions.map(&:name))
      assert_equal([], actions.first.args)
      assert_equal(["/done", true, true], actions.last.args)
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
