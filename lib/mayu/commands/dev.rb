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

        Configuration.with(:development) do |config|
          Mayu::Server.new(
            config:,
            worker_count: 1,
            load_environment: ->(metrics:) do
              environment = Environment.with_config(config, metrics:)
              if config.server.hmr?
                environment.on_start { environment.start_watcher }
              end
              environment
            end
          ).run
        end
      end
    end
  end
end
