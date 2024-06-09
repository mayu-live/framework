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
        require_relative "../system_config"

        Sync do
          Modules::System.use("app", **SYSTEM_CONFIG) do |system|
            Configuration.with do |config|
              config = config[:dev]

              system.start_watch

              Async do
                system.process_assets(
                  out_dir: ".assets",
                  concurrency: 2,
                  forever: true
                )
              end

              server = Mayu::Server.new(config)
              server.run
            end
          end

          Server.new(config.fetch(:dev)).run
        end
      end
    end
  end
end
