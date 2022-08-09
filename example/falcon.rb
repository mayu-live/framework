#!/usr/bin/env -S falcon host
# frozen_string_literal: true

require "toml-rb"
require "pry"
require "prometheus/client"
require "prometheus/client/data_stores/direct_file_store"

load :rack, :supervisor

ENV["MAYU_ENV"] = "production"

PROJECT_ROOT = File.dirname(__FILE__)

config =
  TomlRB.load_file(
    File.join(PROJECT_ROOT, "mayu.toml"),
    symbolize_keys: true
  ).fetch(:prod, {})

PROMETHEUS_STORE_DIR = File.join(PROJECT_ROOT, "tmp", "prometheus")

Dir[File.join(PROMETHEUS_STORE_DIR, "*.bin")].each { |file| File.unlink(file) }

Prometheus::Client.config.data_store =
  Prometheus::Client::DataStores::DirectFileStore.new(dir: PROMETHEUS_STORE_DIR)

hostname = config.fetch(:hostname, "localhost")
port = config.fetch(:port, 3000)

rack(hostname) do
  endpoint(
    Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}").with(
      protocol: Async::HTTP::Protocol::HTTP2
    )
  )
end

rack("metrics") do
  endpoint(
    Async::HTTP::Endpoint.parse("http://0.0.0.0:9091").with(
      protocol: Async::HTTP::Protocol::HTTP11
    )
  )

  config_path("config.metrics.ru")
end

supervisor
