#!/usr/bin/env falcon --verbose serve -c --threaded --count 8
# typed: false
# frozen_string_literal: true

root_dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.join(root_dir, '..', 'lib'))

require "mayu/server2"

use Rack::CommonLogger
run Mayu::Server2.build(root_dir)
