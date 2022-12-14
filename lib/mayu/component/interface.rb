# typed: strict

require_relative "handler_ref"

module Mayu
  module Component
    module Interface
      extend T::Sig
      extend T::Helpers
      interface!
    end

    module DSL
      extend T::Sig
      extend T::Helpers
    end
  end
end
