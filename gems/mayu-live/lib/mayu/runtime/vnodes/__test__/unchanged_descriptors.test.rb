#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::UnchangedDescriptorsTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  RENDERS = Hash.new(0)

  class Counter < Mayu::Component::Base
    def render
      RENDERS[:counter] += 1
      H[:p, "counted"]
    end
  end

  class Consumer < Mayu::Component::Base
    def render
      RENDERS[:consumer] += 1
      H[:output, @__context[:theme].to_s]
    end
  end

  # The same descriptor object on every render of the provider.
  CONSUMER = H[Consumer]

  class Provider < Mayu::Component::Base
    def initialize
      @theme = "light"
    end

    def set_theme(theme)
      @theme = theme
      rerender!
    end

    def render
      H.context(theme: @theme) { CONSUMER }
    end
  end

  def setup
    RENDERS.clear
  end

  def test_a_head_flush_leaves_components_with_unchanged_descriptors_alone
    descriptor = H[:body, H[:head, H[:title, "T"]], H[:main, H[Counter]]]
    engine = Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)
    collector = Mayu::Runtime::VNodes::CommandCollector.new
    assert_equal(1, RENDERS[:counter])

    engine.root.replace_route_assets(stylesheets: ["/new.css"], scripts: [])
    engine.flush_head(collector)

    assert_equal(1, RENDERS[:counter])
    refute_empty(collector.commands, "the head itself is still updated")
  end

  def test_a_new_descriptor_still_rerenders
    engine = Mayu::Runtime::Engine.new(H[:body, H[Counter]], metrics: NullMetrics.new)

    engine.update(H[:body, H[Counter]])

    assert_equal(2, RENDERS[:counter])
  end

  def test_a_context_change_rerenders_a_consumer_that_reuses_its_descriptor
    engine = Mayu::Runtime::Engine.new(H[:body, H[Provider]], metrics: NullMetrics.new)

    run_engine_instance(engine) do
      provider = find_component(engine.root, Provider).instance_variable_get(:@instance)
      wait_until { provider.respond_to?(:rerender!) }
      assert_equal(1, RENDERS[:consumer])

      provider.set_theme("dark")

      patches =
        dequeue_until(engine) do |commands|
          commands.any? do |command|
            command.is_a?(Mayu::Runtime::Commands::SetTextContent) && command.content == "dark"
          end
        end
      refute_nil(patches, "expected the consumer to show the new theme")
      assert_equal(2, RENDERS[:consumer])
    end
  end
end
