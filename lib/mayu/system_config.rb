# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "modules"

module Mayu
  SYSTEM_CONFIG = {
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
      Mayu::Modules::Rules::Rule[/\.js$/, Mayu::Modules::Loaders::JavaScript[]],
      Mayu::Modules::Rules::Rule[
        /\.(png|jpe?g|webp|gif)$/,
        Mayu::Modules::Loaders::Image[]
      ],
      Mayu::Modules::Rules::Rule[/\.svg$/, Mayu::Modules::Loaders::SVG[]]
    ]
  }
end
