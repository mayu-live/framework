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

config =
  TomlRB.load_file(
    File.join(PROJECT_ROOT, "mayu.toml"),
    symbolize_keys: true
  ).fetch(:prod, {})

config =
  Mayu::Server::Config.new(
    SECRET_KEY: ENV.fetch("SECRET_KEY") { raise "SECRET_KEY is not set" },
    MAX_SESSIONS: config.fetch(:max_sessions, 16).to_i,
    KEEPALIVE_SECONDS: config.fetch(:keepalive_seconds, 3).to_f,
    PRINT_CAPACITY_INTERVAL: config.fetch(:print_capacity_interval, 5).to_f,
    HEARTBEAT_INTERVAL_SECONDS: ENV.fetch("heartbeat_interval", 0.5).to_f,
  )

cluster = Mayu::Server::Cluster.new(:worker)
metrics = Mayu::Metrics.new(cluster:)

T.bind(self, Rack::Builder)

run Mayu::Server.build(cluster:, metrics:, config:)
