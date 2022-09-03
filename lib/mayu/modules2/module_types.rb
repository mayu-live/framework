# typed: strict

require_relative "mod"
require_relative "module_types/base"
require_relative "module_types/ruby"
require_relative "module_types/css"
require_relative "module_types/image"

module Mayu
  module Modules2
    module ModuleTypes
      extend T::Sig

      sig { params(mod: Mod).returns(Base) }
      def self.load(mod)
        self.for(mod).load(mod)
      end

      sig { params(mod: Mod).returns(T.class_of(Base)) }
      def self.for(mod)
        case mod.extname
        when ".rb"
          Ruby
        when ".css"
          CSS
        when ".png", ".jpg", ".jpeg"
          Image
        else
          raise "No module type for #{mod.path}"
        end
      end
    end
  end
end
