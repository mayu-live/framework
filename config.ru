#!/usr/bin/env falcon --verbose serve -c --threaded --count 4
# typed: false
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "lib/mayu"
require_relative "lib/mayu/server"

run Mayu::Server
