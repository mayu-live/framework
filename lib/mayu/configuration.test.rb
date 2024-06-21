#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"

require_relative "configuration"

class Mayu::Configuration::Test < Minitest::Test
  def test_configuration
    filename = File.join(__dir__, "__test__", "configuration", "test.toml")
    config = Mayu::Configuration.load(filename, "development")
  end
end
