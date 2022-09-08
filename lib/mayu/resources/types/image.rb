# typed: strict

require_relative "base"

module Mayu
  module Resources
    module Types
      class Image < Base
        class ImageOptions < T::Struct
          const :width, Integer
        end

        sig { override.params(resource: Resource).returns(T.attached_class) }
        def self.load(resource)
          new(resource)
        end

        sig { params(resource: Resource).void }
        def initialize(resource)
          super(resource)
          @asset = Assets::Asset.from_file(path: resource.path)
        end

        sig { params(options: ImageOptions).returns(Assets::Asset) }
        def add_version(**options)
          Assets::Asset.new(
            Digest::SHA256.digest(@resource.hash + options.serialize)
          )
        end
      end
    end
  end
end
