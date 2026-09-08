#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require_relative "../commands"

class Mayu::Commands::TestTest < Minitest::Test
  def test_is_listed_after_dev
    output = StringIO.new

    Mayu::Commands::Application.new([], output:).call

    assert_includes(
      output.string,
      "One of: init, dev, test, build, start, routes, graph, transform"
    )
  end

  def test_worker_command_reenters_mayu
    command = Mayu::Commands::Test.new([])
    worker_command = command.send(:worker_command)

    assert_equal(RbConfig.ruby, worker_command.first)
    assert_equal("test", worker_command.last)
    assert_equal("mayu", File.basename(worker_command.fetch(1)))
  end

  def test_description_mentions_mayu
    assert_equal(
      "Run and watch Mayu application tests.",
      Mayu::Commands::Test.description
    )
  end
end
