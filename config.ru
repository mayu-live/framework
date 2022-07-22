#!/usr/bin/env falcon --verbose serve -c --threaded --count 2
# typed: false
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "lib/mayu"
require_relative "lib/mayu/server2"

use Mayu::Server2

run lambda { |env| [404, [], []] }
