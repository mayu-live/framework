# typed: strict

require_relative "resource"
require_relative "module_types/base"
require_relative "module_types/ruby"
require_relative "module_types/css"
require_relative "module_types/image"

module Mayu
  module Resources
    module Types
      extend T::Sig

      sig { params(resource: Resource).returns(Base) }
      def self.load(resource)
        self.for(resource).load(resource)
      end

      sig { params(resource: Resource).returns(T.class_of(Base)) }
      def self.for(resource)
        case resource.extname
        when ".rb"
          Ruby
        when ".css"
          CSS
        when ".png", ".jpg", ".jpeg"
          Image
        else
          raise "No module type for #{resource.path}"
        end
      end
    end
  end
end
