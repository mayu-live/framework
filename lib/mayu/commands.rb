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

module Mayu
  module Commands
    class Application < Samovar::Command
      nested :command,
             {
               "dev" => Dev,
               "transform" => Transform,
               "routes" => Routes,
               "build" => Build,
               "start" => Start
             }

      def call
        @command.call if @command
      end
    end

    def self.call(argv)
      Application.call(argv)
    end
  end
end
