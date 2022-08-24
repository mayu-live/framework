#!/usr/bin/env falcon --verbose serve -c --threaded --count 8
# typed: strict
# frozen_string_literal: true

PROJECT_ROOT = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.join(PROJECT_ROOT, "..", "lib"))

require "toml-rb"
require "mayu/metrics"
require "mayu/server/cluster"
require "mayu/server/config"
require "mayu/server"

mayu_config =
  TomlRB.load_file(
    File.join(PROJECT_ROOT, "mayu.toml"),
    symbolize_keys: true
  ).fetch(:prod, {})

config =
  Mayu::Server::Config.new(
    SECRET_KEY: ENV.fetch("SECRET_KEY") { raise "SECRET_KEY is not set" },
    MAX_SESSIONS: mayu_config.fetch(:max_sessions, 16).to_i,
    KEEPALIVE_SECONDS: mayu_config.fetch(:keepalive_seconds, 3).to_f,
    PRINT_CAPACITY_INTERVAL: mayu_config.fetch(:print_capacity_interval, 5).to_f,
    HEARTBEAT_INTERVAL_SECONDS: mayu_config.fetch("heartbeat_interval", 0.5).to_f,
    NATS_SERVER: ENV.fetch("NATS_SERVER") { raise "NATS_SERVER is not set" },
    FLY_APP_NAME: ENV.fetch("FLY_APP_NAME") { raise "FLY_APP_NAME is not set" },
    FLY_ALLOC_ID: ENV.fetch("FLY_ALLOC_ID") { raise "FLY_ALLOC_ID is not set" },
    FLY_REGION: ENV.fetch("FLY_REGION") { raise "FLY_REGION is not set" },
  )

cluster = Mayu::Server::Cluster.new(:worker)
metrics = Mayu::Metrics.new(cluster:)

T.bind(self, Rack::Builder)

run Mayu::Server.build(cluster:, metrics:, config:)
