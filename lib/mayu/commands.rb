# frozen_string_literal: true

require "samovar"
require_relative "commands/dev"
require_relative "commands/transform"

module Mayu
  module Commands
    class Application < Samovar::Command
      nested :command, { "dev" => Dev, "transform" => Transform }

      def call
        @command.call if @command
      end
    end

    def self.call(argv)
      Application.call(argv)
    end
  end
end
