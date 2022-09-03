# typed: strict

require_relative "base"

module Mayu
  module Modules2
    module ModuleTypes
      class Image < Base
        sig { override.params(mod: Mod).returns(T.attached_class) }
        def self.load(mod)
          new(mod)
        end

        sig { params(mod: Mod).void }
        def initialize(mod)
          super(mod)
        end
      end
    end
  end
end
