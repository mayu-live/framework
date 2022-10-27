# frozen_string_literal: true
# typed: ignore

require "sorbet-runtime"
require "minitest/reporters"
require "pry"

Minitest::Reporters.use!(
  Minitest::Reporters::DefaultReporter.new,
  ENV,
  Minitest.backtrace_filter
)
