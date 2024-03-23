require_relative "transformers/css"

module Mayu
  module Modules
    module Loaders
      CSS = Data.define do
        def call(loading_file)
          loading_file
            .maybe_load_source
            .transform { Transformers::CSS.transform(_1.path, _1.source) }
            .tap { puts _1.source }
        end
      end
    end
  end
end
