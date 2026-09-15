# frozen_string_literal: true

require "bundler/setup"
require "standard/rake"
require "fileutils"

GEMS = %w[mayu-live].freeze
CLIENT_WORKSPACE = "gems/mayu-live/lib/mayu/client"

unless ENV["BUNDLE_WITHOUT"].to_s.split(":").include?("test")
  require "minitest/test_task"
  require "minitest/reporters"

  Minitest::TestTask.create(:test) do |t|
    GEMS.each { |name| t.libs << "gems/#{name}/lib" }
    t.warning = false
    t.test_globs = GEMS.map { |name| "gems/#{name}/lib/**/*.test.rb" }
  end

  task :client_build do
    sh "npm", "run", "build"
  end

  task test: :client_build

  task default: :test
end

desc "Build all gem packages into pkg/"
task :build do
  require_relative "gems/mayu-live/lib/mayu/version"

  sh "npm", "-w", CLIENT_WORKSPACE, "run", "build:production"
  FileUtils.mkdir_p("pkg")
  GEMS.each do |name|
    Dir.chdir("gems/#{name}") do
      sh "gem", "build", "#{name}.gemspec", "--output", "../../pkg/#{name}-#{Mayu::VERSION}.gem"
    end
  end
end

namespace :profile do
  desc "Profile vnode update path with Vernier"
  task :vnodes_update do
    sh "bundle", "exec", "ruby", "gems/mayu-live/lib/mayu/runtime/vnodes/__test__/update_profile.rb"
  end
end
