# frozen_string_literal: true
# typed: strict

module Mayu
  module Resources
    module Generators
      class Base
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { abstract.params(asset_dir: String).void }
        def process(asset_dir)
        end
      end
    end
  end
end
