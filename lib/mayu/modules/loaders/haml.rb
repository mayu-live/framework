require_relative "transformers/ruby"
require_relative "transformers/haml"

module Mayu
  module Modules
    module Loaders
      Haml =
        Data.define(:component_base_class, :using, :factory) do
          def self.[](component_base_class:, using: [], factory: "H")
            new(component_base_class:, using:, factory:)
          end

          def call(loading_file)
            loading_file
              .maybe_load_source
              .transform do
                Transformers::Haml.transform(
                  _1.source,
                  _1.path,
                  factory:
                ).output
              end
              .transform do
                Transformers::Ruby.transform(
                  _1.source,
                  _1.path,
                  component_base_class:,
                  using:
                )
              end
          end
        end
    end
  end
end
