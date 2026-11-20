# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  # Process resource setup in `mayu.rb`, next to `mayu.toml`. A Sequel app
  # configures its database before model definitions read table schemas,
  # disconnects the parent's connections before forking, and starts a
  # PostgreSQL listener in each worker:
  #
  #   require_relative "db/database"
  #   Database.connect
  #
  #   Mayu.setup do |setup|
  #     setup.before_fork { Database.disconnect }
  #     setup.on_worker do |environment|
  #       environment.on_start { Database.start_listener }
  #     end
  #   end
  #
  # The file is plain Ruby, loaded once in the server's parent process, and is
  # not hot reloaded. Request/session policies belong in `app/hooks.rb`, which
  # supports project imports and HMR; process setup uses require/require_relative.
  class Setup
    FILENAME = "mayu.rb"

    def self.load(root)
      setup = new
      path = File.join(root, FILENAME)
      return setup unless File.exist?(path)

      @loading = setup
      Kernel.load(path)
      setup
    ensure
      @loading = nil
    end

    def self.loading
      @loading or raise "Mayu.setup can only be called from #{FILENAME}"
    end

    def initialize
      @before_fork = []
      @on_worker = []
    end

    # Runs in the controller after the app is loaded and before the workers
    # are forked, on start and on every restart.
    def before_fork(&block)
      @before_fork << block
    end

    # Runs in each worker with its Environment, before the worker serves.
    def on_worker(&block)
      @on_worker << block
    end

    def run_before_fork
      @before_fork.each(&:call)
    end

    def run_on_worker(environment)
      @on_worker.each { it.call(environment) }
    end
  end

  def self.setup
    yield Setup.loading
  end
end
