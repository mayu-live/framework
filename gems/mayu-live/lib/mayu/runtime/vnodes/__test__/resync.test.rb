#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::ResyncTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  Commands = Mayu::Runtime::Commands

  class Counter < Mayu::Component::Base
    def initialize
      @count = 0
    end

    def handle_increment
      @count += 1
      rerender!
    end

    def handle_alert
      @count += 1
      rerender!
      browser.alert("Count: #{@count}")
    end

    def render
      H[:button, "Count: #{@count}", onclick: H.callback(self, :handle_increment)]
    end
  end

  CLOCK = Mayu::Runtime::Descriptors::CustomElement["my-clock", "my-clock.js"]

  class Loader < Mayu::Component::Base
    def initialize
      @loaded = false
    end

    def handle_load
      @loaded = true
      rerender!
    end

    def render
      H[:div, (H[CLOCK] if @loaded)]
    end
  end

  def counter(engine)
    component = find_component(engine.root, Counter)
    instance = component.instance_variable_get(:@instance)
    wait_until { instance.respond_to?(:rerender!) }
    instance
  end

  def next_batch(engine)
    Async::Task.current.with_timeout(0.5) { engine.dequeue_batch }
  end

  def test_resync_commands_carry_the_page_its_ids_and_its_listeners
    engine = Mayu::Runtime::Engine.new(H[:body, H[Counter]], metrics: NullMetrics.new)

    resync, *listeners = engine.resync_commands

    assert_instance_of(Commands::Resync, resync)
    assert(resync.html.start_with?("<!DOCTYPE html>\n<html>"))
    assert_includes(resync.html, "<button>Count: 0</button>")
    assert_equal(engine.dom_id_tree, resync.id_tree)
    assert_equal(engine.listener_commands, listeners)
    assert_equal(["click"], listeners.map(&:name))
  end

  def test_resync_commands_do_not_update_the_tree
    run_engine(H[:body, H[Counter]]) do |engine|
      counter(engine).handle_increment

      # The rerender is queued but has not run: the page is still as the
      # browser was told.
      assert_includes(engine.resync_commands.first.html, "Count: 0")

      batch = next_batch(engine)
      assert_equal([Commands::SetTextContent], batch.commands.map(&:class))
    end
  end

  def test_a_resync_follows_the_updates_queued_before_it_and_replaces_their_commands
    run_engine(H[:body, H[Counter]]) do |engine|
      counter(engine).handle_alert
      engine.resync

      batch = next_batch(engine)
      classes = batch.commands.map(&:class)

      assert_equal(Commands::Resync, classes.first)
      assert_includes(batch.commands.first.html, "Count: 1")
      refute_includes(classes, Commands::SetTextContent)
      # What is not a DOM update still arrives, after the page.
      assert_equal(Commands::BrowserAction, classes.last)
      assert_equal([Commands::SetListener], classes[1...-1].uniq)

      assert_no_patches(engine)
    end
  end

  # The page has the element, but only the command tells the browser where
  # its module is.
  def test_a_resync_keeps_what_its_pass_sends_besides_dom_updates
    run_engine(H[:body, H[Loader]]) do |engine|
      component = find_component(engine.root, Loader)
      instance = component.instance_variable_get(:@instance)
      wait_until { instance.respond_to?(:rerender!) }

      instance.handle_load
      engine.resync

      batch = next_batch(engine)
      classes = batch.commands.map(&:class)

      assert_equal(Commands::Resync, classes.first)
      assert_includes(batch.commands.first.html, "<my-clock>")
      assert_includes(classes, Commands::RegisterCustomElement)
      refute_includes(classes, Commands::CreateTree)
      refute_includes(classes, Commands::ReplaceChildren)
    end
  end

  # The command that named the module went out in an earlier batch, which
  # the browser may never have seen.
  def test_resync_commands_name_the_modules_of_the_custom_elements
    run_engine(H[:body, H[Loader]]) do |engine|
      component = find_component(engine.root, Loader)
      instance = component.instance_variable_get(:@instance)
      wait_until { instance.respond_to?(:rerender!) }

      instance.handle_load
      next_batch(engine)

      assert_includes(
        engine.resync_commands,
        Commands::RegisterCustomElement[CLOCK.name, CLOCK.path]
      )
    end
  end

  def test_updates_after_a_resync_are_ordinary_patches
    run_engine(H[:body, H[Counter]]) do |engine|
      instance = counter(engine)
      engine.resync
      assert_equal(Commands::Resync, next_batch(engine).commands.first.class)

      instance.handle_increment

      batch = next_batch(engine)
      assert_equal([Commands::SetTextContent], batch.commands.map(&:class))
      assert_equal("Count: 1", batch.commands.first.content)
    end
  end

  def test_several_requests_in_one_pass_send_one_page
    run_engine(H[:body, H[Counter]]) do |engine|
      3.times { engine.resync }

      assert_equal(Commands::Resync, next_batch(engine).commands.first.class)
      assert_no_patches(engine)
    end
  end

  def test_a_stopped_engine_queues_the_page_directly
    engine = Mayu::Runtime::Engine.new(H[:body, H[Counter]], metrics: NullMetrics.new)

    Async do
      engine.resync
      assert_equal(Commands::Resync, next_batch(engine).commands.first.class)
    end.wait
  end

  def test_take_queued_batches_empties_the_queue
    engine = Mayu::Runtime::Engine.new(H[:body, H[Counter]], metrics: NullMetrics.new)
    engine.enqueue_command(Commands::Pong[1])
    engine.enqueue_command(Commands::Pong[2])

    assert_equal(
      [[Commands::Pong[1]], [Commands::Pong[2]]],
      engine.take_queued_batches.map(&:commands)
    )
    assert_empty(engine.take_queued_batches)
  end
end
