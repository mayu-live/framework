# frozen_string_literal: true

require "bundler/setup"
require "standard/rake"
require "fileutils"

GEMS = %w[mayu-live mayu-build].freeze
CLIENT_WORKSPACE = "gems/mayu-live/lib/mayu/client"

unless ENV["BUNDLE_WITHOUT"].to_s.split(":").include?("test")
  require "minitest/test_task"
  require "minitest/reporters"

  # Every suite runs with both gems on the load path: mayu-live's tests use
  # mayu-build to compile fixtures, and the runtime boundary test proves the
  # production path still does not need it.
  def minitest_task(name, description, globs)
    Minitest::TestTask.create(name) do |t|
      GEMS.each { |gem_name| t.libs << "gems/#{gem_name}/lib" }
      t.warning = false
      t.test_globs = globs
    end
    Rake::Task[name].comment = description
  end

  namespace :test do
    minitest_task(:live, "Run mayu-live tests", ["gems/mayu-live/lib/**/*.test.rb"])
    minitest_task(:build, "Run mayu-build tests", ["gems/mayu-build/lib/**/*.test.rb"])
  end

  minitest_task(:test, "Run all gem tests", GEMS.map { |name| "gems/#{name}/lib/**/*.test.rb" })

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
