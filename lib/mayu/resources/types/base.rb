# typed: strict

require_relative "../resource"

module Mayu
  module Resources
    module Types
      class Base
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource
        end

        sig { abstract.params(resource: Resource).returns(T.attached_class) }
        def self.load(resource)
        end
      end
    end
  end
end
