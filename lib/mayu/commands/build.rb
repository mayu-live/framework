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
        require_relative "../configuration"
        require_relative "../environment"
        require_relative "../routes"
        require_relative "../component"

        Mayu::Configuration.with do |config|
          config = config.fetch(:prod)

          environment = Mayu::Environment.from_config(config)

          Modules::System.use("app", **SYSTEM_CONFIG) do |system|
            environment.router.all_templates.each do |template|
              system.import(File.join("/pages", template))
            end

            File.write("system.marshal", Marshal.dump(system))
          end
        end
      end
    end
  end
end
