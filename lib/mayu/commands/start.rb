# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Commands
    class Start < Samovar::Command
      self.description = "Start the production server"

      def call
        require_relative "../configuration"
        require_relative "../server"
        require_relative "../component"
        require_relative "../system_config"

        Sync do
          Environment.with(:production) do |environment|
            system = Marshal.load(File.read("app.mayu-bundle"))

            system.use do |system|
              Mayu::Server.new(environment).run.wait
            rescue => e
              Console.logger(self, e)
              raise
            ensure
              puts "\e[44mStopping dev\e[0m"
            end
          end
        end
      end
    end
  end
end
