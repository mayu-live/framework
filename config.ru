#!/usr/bin/env falcon --verbose serve -c --threaded --count 8
# typed: false
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "lib/mayu"
require_relative "lib/mayu/server2"

use Rack::CommonLogger
run Mayu::Server2::App
