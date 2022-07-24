# typed: ignore

require "minitest/test_task"

Minitest::TestTask.create(:test) do |t|
  t.libs << "lib"
  t.warning = false
  t.test_globs = ["lib/**/*.test.rb"]
end

task :default => :test
