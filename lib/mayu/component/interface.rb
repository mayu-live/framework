# typed: strict

require_relative "handler_ref"
require_relative "../markup"

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

      sig { overridable.params(path: String).returns(T.class_of(Base)) }
      def self.import(path)
      end
    end
  end
end
