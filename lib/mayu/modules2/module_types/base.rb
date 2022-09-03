# typed: strict

require_relative "../mod"

module Mayu
  module Modules2
    module ModuleTypes
      class Base
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { params(mod: Mod).void }
        def initialize(mod)
          @mod = mod
        end

        sig { abstract.params(mod: Mod).returns(T.attached_class) }
        def self.load(mod)
        end
      end
    end
  end
end
