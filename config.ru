#!/usr/bin/env falcon --verbose serve -c --threaded --count 4
# typed: false
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "lib/mayu"
require_relative "lib/mayu/server"

use Rack::CommonLogger

JS_ROOT = File.join(File.dirname(__FILE__), "lib", "mayu", "client", "dist")
JS_FILES =
  Dir[File.join(JS_ROOT, '*.js')]
    .map { File.basename(_1) }
    .map { ["/__mayu/#{_1}", _1] }
    .to_h

use Rack::Static,
  urls: JS_FILES,
  root: JS_ROOT

run Mayu::Server
