# frozen_string_literal: true
# typed: ignore

require "minitest/reporters"

Minitest::Reporters.use!(
  Minitest::Reporters::DefaultReporter.new,
  ENV,
  Minitest.backtrace_filter
)
