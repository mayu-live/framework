#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require_relative "setup"
require_relative "environment"

class Mayu::SetupTest < Minitest::Test
  def self.calls = @calls ||= []

  def test_without_a_setup_file_the_hooks_do_nothing
    Dir.mktmpdir("mayu-setup") do |root|
      setup = Mayu::Setup.load(root)

      setup.run_before_fork
      setup.run_on_worker(Object.new)
    end
  end

  def test_the_setup_file_registers_hooks_for_fork_and_workers
    Dir.mktmpdir("mayu-setup") do |root|
      File.write(File.join(root, "mayu.rb"), <<~RUBY)
        Mayu.setup do |setup|
          setup.before_fork { Mayu::SetupTest.calls << :before_fork }
          setup.on_worker do |environment|
            Mayu::SetupTest.calls << [:on_worker, environment]
            environment.on_start do |app|
              Mayu::SetupTest.calls << [:start, app]
              started = Object.new
              def started.stop = Mayu::SetupTest.calls << :stop
              started
            end
          end
        end
      RUBY

      Mayu::SetupTest.calls.clear
      setup = Mayu::Setup.load(root)
      assert_empty(Mayu::SetupTest.calls)

      setup.run_before_fork
      assert_equal([:before_fork], Mayu::SetupTest.calls)

      environment = Mayu::Environment.allocate
      environment.instance_variable_set(:@start_hooks, [])
      setup.run_on_worker(environment)
      environment.start(:app)
      environment.stop

      assert_equal(
        [:before_fork, [:on_worker, environment], [:start, :app], :stop],
        Mayu::SetupTest.calls
      )
    end
  end

  def test_setup_outside_the_setup_file_is_an_error
    error = assert_raises(RuntimeError) { Mayu.setup {} }

    assert_includes(error.message, "mayu.rb")
  end
end
