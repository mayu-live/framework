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
        require_relative "../modules"
        require_relative "../component"

        system_config = {
          extensions: ["", ".haml", ".rb"],
          rules: [
            Mayu::Modules::Rules::Rule[/\.rb$/, Mayu::Modules::Loaders::Ruby[]],
            Mayu::Modules::Rules::Rule[
              /\.haml$/,
              Mayu::Modules::Loaders::Haml[
                component_base_class: "Mayu::Component::Base",
                using: ["Mayu::Component::CSSUnits::Refinements"],
                factory: "H"
              ]
            ],
            Mayu::Modules::Rules::Rule[/\.css$/, Mayu::Modules::Loaders::CSS[]],
            Mayu::Modules::Rules::Rule[
              /\.js$/,
              Mayu::Modules::Loaders::JavaScript[]
            ],
            Mayu::Modules::Rules::Rule[
              /\.(png|jpe?g|webp|gif|svg)$/,
              Mayu::Modules::Loaders::Image[]
            ]
          ]
        }

        Sync do
          Modules::System.use("app", **system_config) do |system|
            Configuration.with do |config|
              config = config[:dev]

              system.start_watch

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
