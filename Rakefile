# frozen_string_literal: true
# typed: ignore

require "bundler/setup"
require "minitest/test_task"
require "minitest/reporters"
require "sorbet-runtime"

Minitest::TestTask.create(:test) do |t|
  t.libs << "lib"
  t.warning = false
  t.test_globs = ["lib/**/*.test.rb"]
end

task default: :test
