# typed: strict
# frozen_string_literal: true

require "minitest/reporters"
require "pry"

$LOAD_PATH.unshift(File.join(__dir__, "gems", "mayu-live", "lib"))

Minitest::Reporters.use!(
  Minitest::Reporters::DefaultReporter.new,
  ENV,
  Minitest.backtrace_filter
)
