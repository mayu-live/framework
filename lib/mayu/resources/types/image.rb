# typed: strict

require_relative "base"

module Mayu
  module Resources
    module Types
      class Image < Base
        sig { override.params(mod: Resource).returns(T.attached_class) }
        def self.load(mod)
          new(mod)
        end

        sig { params(mod: Resource).void }
        def initialize(mod)
          super(mod)
        end

        sig { params(options: ImageOptions).returns(Assets::Asset) }
      end
    end
  end
end
