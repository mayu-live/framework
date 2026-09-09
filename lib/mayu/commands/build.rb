# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Commands
    class Build < Samovar::Command
      self.description = "Build app for production"

      options do
        option(
          "--filename <string>",
          "Filename of the generated bundle",
          default: "app.mayu-bundle"
        )

        option(
          "--concurrency <number>",
          "Number of concurrent tasks for generating assets",
          default: 4
        ) { it.to_i }
      end

      def call
        require_relative "../configuration"
        require_relative "../klenod"

        Sync do
          elapsed =
            Async::Clock.measure do
              Configuration.with(:development) do |config|
                Klenod::Configuration.load(
                  root: config.root,
                  mode: :production
                ).build(
                  output: File.expand_path(options[:filename]),
                  asset_generation_concurrency: options[:concurrency]
                )
              end
            rescue => e
              Console.logger.error(self, e)
              raise
            end

          puts format(
            "\e[32mBuilt \e[1m%s\e[22m in \e[1m%.2fs\e[0m",
            options[:filename],
            elapsed
          )
        end
      end
    end
  end
end
