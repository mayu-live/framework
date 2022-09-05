# typed: strict

require_relative "../mod"

module Mayu
  module Resources
    module Types
      class Base
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { params(mod: Resource).void }
        def initialize(mod)
          @mod = mod
        end

        sig { abstract.params(mod: Resource).returns(T.attached_class) }
        def self.load(mod)
        end
      end
    end
  end
end
