# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "samovar"
require "mayu/version"

require_relative "commands/init"
require_relative "commands/dev"
require_relative "commands/test"
require_relative "commands/build"
require_relative "commands/start"
require_relative "commands/routes"
require_relative "commands/graph"
require_relative "commands/transform"
require_relative "commands/lsp"

module Mayu
  module Build
    # The full `mayu` command line. `Mayu::CLI` in mayu-live hands every
    # invocation here whenever this gem is installed.
    module CLI
      class Application < Samovar::Command
        nested :command,
          {
            "init" => Commands::Init,
            "dev" => Commands::Dev,
            "test" => Commands::Test,
            "build" => Commands::Build,
            "start" => Commands::Start,
            "routes" => Commands::Routes,
            "graph" => Commands::Graph,
            "transform" => Commands::Transform,
            "lsp" => Commands::Lsp
          }

        def call
          print_header unless quiet_command?

          @command ? @command.call : print_usage
        end

        private

        # Commands whose stdout is consumed by another program.
        def quiet_command?
          klass = @command.class
          klass.respond_to?(:quiet?) && klass.quiet?
        end

        def print_header
          puts "\e[1;95mMayu v#{Mayu::VERSION}\e[0m"
        end
      end

      def self.call(argv)
        Application.call(argv)
      end
    end
  end
end
