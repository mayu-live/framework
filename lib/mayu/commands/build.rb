# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Commands
    class Build < Samovar::Command
      self.description = "Build app for production"

      def call
        require_relative "../system_config"
        require_relative "../environment"
        require_relative "../routes"
        require_relative "../component"

        Sync do
          Environment.with(:production) do |environment|
            Modules::System.use("app", **SYSTEM_CONFIG) do |system|
              environment.router.all_templates.each do |template|
                system.import(File.join("/pages", template))
              end

              system.generate_assets(
                environment.assets_dir,
                concurrency: 4,
                forever: false
              ).wait

              File.write("system.marshal", Marshal.dump(system))
            rescue => e
              Console.logger(self, e)
              raise
            end
          end
        end
      end
    end
  end
end
