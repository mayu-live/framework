#!/usr/bin/env falcon --verbose serve -c --threaded --count 8
# typed: false
# frozen_string_literal: true

root = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.join(root, "..", "lib"))

require "mayu/dev_server"

run Mayu::DevServer.build_metrics_app(root:)
