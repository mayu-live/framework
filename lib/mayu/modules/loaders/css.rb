# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "transformers/css"

module Mayu
  module Modules
    module Loaders
      CSS =
        Data.define do
          def call(loading_file)
            loading_file.maybe_load_source.transform do
              Transformers::CSS.transform(_1.path, _1.source)
            end
            # .tap { puts _1.source }
          end
        end
    end
  end
end
