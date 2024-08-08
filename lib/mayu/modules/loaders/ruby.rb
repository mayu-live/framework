# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "transformers/ruby"

module Mayu
  module Modules
    module Loaders
      Ruby =
        Data.define do
          def call(loading_file)
            loading_file.maybe_load_source.transform do
              Transformers::Ruby.transform(
                _1.source,
                _1.path,
                enable_assets: false
              )
            end
          end
        end
    end
  end
end
