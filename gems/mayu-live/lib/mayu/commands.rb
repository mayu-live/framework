# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "warning_filter"
require "samovar"
require_relative "commands/start"
require_relative "version"

module Mayu
  module Commands
    # Everything except `start` needs the mayu-build gem. These descriptions
    # keep `--help` stable when it is not installed, and each placeholder
    # explains what to install.
    BUILD_COMMANDS = {
      "init" => "Initialize a new Mayu app",
      "dev" => "Start the development server",
      "test" => "Run and watch Mayu application tests.",
      "build" => "Build app for production",
      "routes" => "Print routes",
      "graph" => "Export a Mayu bundle as a Graphviz graph.",
      "transform" => "Inspect a Klenod-transformed module",
      "lsp" => "Start a language server for editors."
    }.freeze

    ORDER = %w[init dev test build start routes graph transform lsp].freeze

    class MissingBuildCommand < Samovar::Command
      def self.define(name, description)
        Class.new(self) do
          self.description = "#{description} (requires the mayu-build gem)"
          define_singleton_method(:command_name) { name }
        end
      end

      def call
        output.puts "\e[31m#{self.class.command_name} requires the mayu-build gem.\e[0m"
        output.puts "Add it to your Gemfile's development group and run bundle install."
        1
      end
    end

    def self.build_commands
      require "mayu/build/commands"
      Mayu::Build::Commands::COMMANDS
    rescue LoadError => error
      raise unless error.path == "mayu/build/commands"

      BUILD_COMMANDS.to_h do |name, description|
        [name, MissingBuildCommand.define(name, description)]
      end
    end

    def self.commands
      build = build_commands
      ORDER.to_h do |name|
        [name, (name == "start") ? Start : build.fetch(name)]
      end
    end

    class Application < Samovar::Command
      nested :command, Commands.commands

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
