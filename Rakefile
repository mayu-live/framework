# frozen_string_literal: true
# typed: ignore

require "bundler/setup"
require "bundler/gem_tasks"
require "standard/rake"

if ENV["DISABLE_SORBET"]
  require_relative "lib/mayu/disable_sorbet"
  Mayu::DisableSorbet.disable_sorbet!
end

unless ENV["BUNDLE_WITHOUT"].to_s.split(":").include?("test")
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
  system("npm", "-w", "lib/mayu/client", "run", "build:production")
  system("gem", "build")
end

namespace :profile do
  desc "Profile vnode update path with Vernier"
  task :vnodes_update do
    sh "bundle", "exec", "ruby", "lib/mayu/runtime/vnodes/__test__/update_profile.rb"
  end
end
