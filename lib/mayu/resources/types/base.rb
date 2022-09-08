# typed: strict

require_relative "../resource"
require_relative "../../assets"

module Mayu
  module Resources
    module Types
      class Base
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { returns(T.nilable(Assets::Asset)) }
        attr_reader :asset

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource
          @asset = T.let(nil, T.nilable(Assets::Asset))
        end

        sig { abstract.params(resource: Resource).returns(T.attached_class) }
        def self.load(resource)
        end
      end
    end
  end
end
