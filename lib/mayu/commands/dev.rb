# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Commands
    class Dev < Samovar::Command
      self.description = "Start the development server"

      def call
        require_relative "../configuration"
        require_relative "../server"

        Sync do
          Configuration.with(:development) do |config|
            Mayu::Server.new(config:, mayu_env: :development).run.wait
          end
        rescue => e
          Console.logger(self, e)
          raise
        end
      end
    end
  end
end
