# frozen_string_literal: true
# typed: ignore

require "sorbet-runtime"
require "minitest/reporters"

Minitest::Reporters.use!(
  Minitest::Reporters::DefaultReporter.new,
  ENV,
  Minitest.backtrace_filter
)
