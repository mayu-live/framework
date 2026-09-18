#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"

require_relative "server"

class Mayu::ServerTest < Minitest::Test
  def test_self_signed_cert_explains_the_missing_localhost_gem
    error =
      assert_raises(Mayu::Server::MissingLocalhostGemError) do
        without_gem("localhost") do
          Mayu::Server.self_signed_cert_ssl_context("localhost")
        end
      end

    assert_includes(error.message, "mayu-build")
    assert_includes(error.message, "self_signed_cert")
  end

  def test_other_load_errors_are_not_mistaken_for_the_missing_gem
    assert_raises(LoadError) do
      without_gem("openssl") do
        Mayu::Server.self_signed_cert_ssl_context("localhost")
      end
    end
  end

  def test_run_reports_the_missing_localhost_gem_and_exits
    server_config =
      Struct.new(:listen, :self_signed_cert?, :h2c?).new("https://localhost:0", true, false)
    config = Struct.new(:server, :log_file).new(server_config, nil)
    server = Mayu::Server.new(config:, load_environment: nil)

    output, = capture_io do
      assert_raises(SystemExit) do
        without_gem("localhost") { server.run }
      end
    end

    assert_includes(output, "self_signed_cert needs the localhost gem")
  end

  def test_h2c_uses_protocol_detection_for_a_plain_http_listener
    server_config =
      Struct.new(:listen, :self_signed_cert?, :h2c?, :shutdown_timeout_seconds).new(
        "http://127.0.0.1:0",
        false,
        true,
        10
      )
    config = Struct.new(:server, :log_file, :metrics, :root).new(server_config, nil, nil, Dir.pwd)
    server = Mayu::Server.new(config:, load_environment: nil)

    endpoint = server.send(:controller).instance_variable_get(:@endpoint)

    assert_equal(Async::HTTP::Protocol::HTTP, endpoint.protocol)
  end

  def test_https_uses_the_endpoints_default_protocol
    server_config =
      Struct.new(:listen, :self_signed_cert?, :h2c?, :shutdown_timeout_seconds).new(
        "https://localhost:0",
        false,
        false,
        10
      )
    config = Struct.new(:server, :log_file, :metrics, :root).new(server_config, nil, nil, Dir.pwd)
    server = Mayu::Server.new(config:, load_environment: nil)

    endpoint = server.send(:controller).instance_variable_get(:@endpoint)

    assert_equal(Async::HTTP::Protocol::HTTPS, endpoint.protocol)
  end

  def test_the_controller_runs_before_fork_before_starting_workers
    calls = []
    server_config = Struct.new(:shutdown_timeout_seconds).new(1)
    metrics_config = Struct.new(:enabled?).new(false)
    config = Struct.new(:server, :metrics, :root).new(server_config, metrics_config, Dir.pwd)

    controller =
      Mayu::Server::Controller.new(
        config:,
        endpoint: nil,
        load_environment: nil,
        before_fork: -> { calls << :before_fork }
      )

    container = Object.new
    container.define_singleton_method(:run) { |**| calls << :run }

    controller.setup(container)

    assert_equal([:before_fork, :run], calls)
  end

  private

  def without_gem(missing_feature, &)
    error = LoadError.new("cannot load such file -- #{missing_feature}")
    error.define_singleton_method(:path) { missing_feature }
    Mayu::Server.stub(:require, ->(_feature) { raise error }, &)
  end
end
