#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "minitest/autorun"
require "tmpdir"
require "fileutils"

require_relative "configuration"

class Mayu::Configuration::Test < Minitest::Test
  def test_find_walks_up_to_the_config_file
    Dir.mktmpdir("mayu-config") do |root|
      path = File.join(root, "mayu.toml")
      File.write(path, "")
      nested = File.join(root, "app", "pages")
      FileUtils.mkdir_p(nested)

      assert_equal(path, Mayu::Configuration.find("mayu.toml", nested))
    end
  end

  def test_find_returns_nil_when_no_config_file_exists
    Dir.mktmpdir("mayu-config") do |root|
      assert_nil(Mayu::Configuration.find("mayu.toml.missing", root))
    end
  end

  def test_shutdown_timeout
    assert_equal(10, Mayu::Configuration::ServerConfig.parse({}).shutdown_timeout_seconds)
    assert_equal(0.25, Mayu::Configuration::ServerConfig.parse({"shutdown_timeout_seconds" => 0.25}).shutdown_timeout_seconds)
    [0, -1, "bad", Float::INFINITY, Float::NAN].each do |value|
      assert_raises(ArgumentError) do
        Mayu::Configuration::ServerConfig.parse({"shutdown_timeout_seconds" => value})
      end
    end
  end

  def test_configuration
    filename = File.join(__dir__, "__test__", "configuration", "test.toml")
    config = Mayu::Configuration.load(filename, "development")

    assert_equal "dev", config.secret_key
    assert_equal "https://localhost:9292", config.server.listen
    assert_equal true, config.server.hmr?
    assert_equal true, config.server.render_exceptions?
    assert_equal true, config.server.self_signed_cert?
    assert_equal false, config.server.h2c?
    assert_equal true, config.server.generate_assets?
    assert_equal 11, config.server.session_timeout_seconds
    assert_equal 12, config.server.transfer_timeout_seconds
    assert_equal 13, config.server.cookie_timeout_seconds

    assert_equal true, config.metrics.enabled?
    assert_equal "http://localhost:9293", config.metrics.listen

    assert_equal File.join(config.root, "tmp/mayu.log"), config.log_file
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
    assert_equal true, config.server.h2c?
    assert_equal false, config.server.generate_assets?
    assert_equal 21, config.server.session_timeout_seconds
    assert_equal 22, config.server.transfer_timeout_seconds
    assert_equal 23, config.server.cookie_timeout_seconds
    assert_nil config.log_file
  ensure
    ENV.delete("SECRET_KEY")
  end

  def test_configuration_missing_environment
    filename = File.join(__dir__, "__test__", "configuration", "test.toml")

    error =
      assert_raises(Mayu::Configuration::EnvironmentNotDefined) do
        Mayu::Configuration.load(filename, "staging")
      end

    assert_match(/staging/, error.message)
  end

  def test_configuration_missing_env_var
    filename = File.join(__dir__, "__test__", "configuration", "test.toml")

    ENV.delete("SECRET_KEY")

    error =
      assert_raises(Mayu::Configuration::EnvironmentVariableNotDefined) do
        Mayu::Configuration.load(filename, "production")
      end

    assert_match(/\$SECRET_KEY/, error.message)
  end
end
