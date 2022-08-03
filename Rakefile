# typed: ignore

require "minitest/test_task"
require "sorbet-runtime"

Minitest::TestTask.create(:test) do |t|
  t.libs << "lib"
  t.warning = false
  t.test_globs = ["lib/**/*.test.rb"]
end

task default: :test
