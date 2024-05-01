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
        /\.(png|jpe?g|webp|gif|svg)$/,
        Mayu::Modules::Loaders::Image[]
      ]
    ]
  }
end
