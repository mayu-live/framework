# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "samovar"
require_relative "commands/dev"
require_relative "commands/transform"
require_relative "commands/routes"
require_relative "commands/build"
require_relative "commands/start"
require_relative "commands/init"
require_relative "version"

module Mayu
  module Commands
    class Application < Samovar::Command
      nested :command,
             {
               "init" => Init,
               "dev" => Dev,
               "transform" => Transform,
               "routes" => Routes,
               "build" => Build,
               "start" => Start
             }

      def call
        print_header

        @command ? @command.call : print_usage
      end

      private

      def print_header
        puts "\e[1;95mMayu v#{Mayu::VERSION}\e[0m"
      end
    end

    def self.call(argv)
      Application.call(argv)
    end
  end
end
