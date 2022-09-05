# typed: strict

require_relative "base"

module Mayu
  module Resources
    module Types
      class Image < Base
        sig { override.params(resource: Resource).returns(T.attached_class) }
        def self.load(resource)
          new(resource)
        end

        sig { params(resource: Resource).void }
        def initialize(resource)
          super(resource)
        end

        sig { params(options: ImageOptions).returns(Assets::Asset) }
      end
    end
  end
end
