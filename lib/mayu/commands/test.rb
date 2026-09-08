# frozen_string_literal: true

require "rbconfig"
require "klenod/test/cli"

module Mayu
  module Commands
    class Test < ::Klenod::Test::CLI::Command
      self.description = "Run and watch Mayu application tests."

      def call
        require_relative "../configuration"
        require_relative "../klenod"
        require_relative "../test/runner"

        Configuration.with(:development) do |config|
          Mayu::Test::Runner.new(
            root: config.root,
            worker_command:,
            output:,
            **runner_options
          ).call
        end
      rescue ::Klenod::Test::ConfigError => error
        output.puts error.message
        1
      end

      private

      def worker_command
        [RbConfig.ruby, Gem.bin_path("mayu-live", "mayu"), "test"]
      end
    end
  end
end
