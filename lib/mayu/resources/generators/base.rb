# frozen_string_literal: true
# typed: strict

module Mayu
  module Resources
    module Generators
      class Base
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { abstract.params(target_path: String).void }
        def process(target_path)
        end
      end
    end
  end
end
