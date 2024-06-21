# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    module Loaders
      Ruby =
        Data.define do
          def call(loading_file)
            loading_file.maybe_load_source.tap { SyntaxTree.parse(_1.source) }
          end
        end
    end
  end
end
