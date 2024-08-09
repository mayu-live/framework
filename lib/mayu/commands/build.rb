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
        ) { _1.to_i }
      end

      def call
        require_relative "../system_config"
        require_relative "../environment"
        require_relative "../routes"
        require_relative "../component"

        Sync do
          elapsed =
            Async::Clock.measure do
              Environment.with(:development) do |environment|
                environment.modules.import("/root.haml")

                environment.router.all_templates.each do |template|
                  environment.modules.import(File.join("/pages", template))
                end

                environment.modules.update_overall_order

                environment
                  .modules
                  .generate_assets(
                    environment.assets_dir,
                    concurrency: options[:concurrency],
                    forever: false
                  )
                  .wait

                File.write(options[:filename], environment.dump)
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
