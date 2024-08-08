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
        require_relative "../component"

        Sync do
          Environment.with(:development) do |environment|
            environment.modules.start_watch

            Async do
              environment.modules.generate_assets(
                environment.assets_dir,
                concurrency: 1,
                forever: true
              )
            end

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
