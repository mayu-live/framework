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

    assert_equal "dev", config.secret_key
    assert_equal "https://localhost:9292", config.server.listen
    assert_equal true, config.server.hmr?
    assert_equal true, config.server.render_exceptions?
    assert_equal true, config.server.self_signed_cert?
    assert_equal true, config.server.generate_assets?
    assert_equal 11, config.server.session_timeout_seconds
    assert_equal 12, config.server.transfer_timeout_seconds
    assert_equal 13, config.server.cookie_timeout_seconds

    assert_equal true, config.metrics.enabled?
    assert_equal "http://localhost:9293", config.metrics.listen
  end

  def test_configuration_production_env
    filename = File.join(__dir__, "__test__", "configuration", "test.toml")

    ENV["SECRET_KEY"] = "secret"
    config = Mayu::Configuration.load(filename, "production")

    assert_equal "secret", config.secret_key
    assert_equal "http://localhost:3000", config.server.listen
    assert_equal false, config.server.hmr?
    assert_equal false, config.server.render_exceptions?
    assert_equal false, config.server.self_signed_cert?
    assert_equal false, config.server.generate_assets?
    assert_equal 21, config.server.session_timeout_seconds
    assert_equal 22, config.server.transfer_timeout_seconds
    assert_equal 23, config.server.cookie_timeout_seconds
  ensure
    ENV.delete("SECRET_KEY")
  end
end
