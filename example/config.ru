#!/usr/bin/env falcon --verbose serve
# typed: false
# frozen_string_literal: true

root = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.join(root, "..", "lib"))

require "prometheus/client"
require "prometheus/client/data_stores/direct_file_store"

PROMETHEUS_STORE_DIR = File.join(root, "tmp", "prometheus")

Prometheus::Client.config.data_store =
  Prometheus::Client::DataStores::DirectFileStore.new(dir: PROMETHEUS_STORE_DIR)

require "mayu/dev_server"

run Mayu::DevServer.build(root:, hot_reload: ENV["MAYU_ENV"] != "production")
