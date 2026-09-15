# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Build
    module Commands
      class Dev < Samovar::Command
        self.description = "Start the development server"

        def call
          require_relative "../../configuration"
          require_relative "../../server"
          require_relative "../../build"

          Mayu::Configuration.with(:development) do |config|
            Mayu::Server.new(
              config:,
              worker_count: 1,
              load_environment: ->(metrics:) do
                provider =
                  Mayu::Build::Configuration.new(root: config.root).development_provider
                environment = Mayu::Environment.new(config, module_provider: provider, metrics:)
                if config.server.hmr?
                  reloader =
                    Mayu::Build::HotReloader.new(
                      provider:,
                      source_dir: environment.app_dir
                    )
                  environment.on_start { |app| reloader.start(app) }
                end
                environment
              end
            ).run
          end
        end
      end
    end
  end
end
