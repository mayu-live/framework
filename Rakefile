# frozen_string_literal: true
# typed: ignore

require "bundler/setup"
require "sorbet-runtime"

unless ENV['BUNDLE_WITHOUT'].to_s.split(":").include?("test")
  require "minitest/test_task"
  require "minitest/reporters"

  Minitest::TestTask.create(:test) do |t|
    t.libs << "lib"
    t.warning = false
    t.test_globs = ["lib/**/*.test.rb"]
  end

  task default: :test
end

task :build do
  Dir.chdir("lib/mayu/client") do
    system("npm", "run", "build:production")
  end

  system("gem", "build")
end
