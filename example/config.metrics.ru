#!/usr/bin/env falcon --verbose serve -c --threaded --count 8
# typed: false
# frozen_string_literal: true

root = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.join(root, "..", "lib"))

require "mayu/server"

run Mayu::Server.build_metrics_app(root:)
