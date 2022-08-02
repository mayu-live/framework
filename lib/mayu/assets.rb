# typed: strict

module Mayu
  module Assets
    class Manager
      extend T::Sig

      class Asset
        extend T::Sig

        sig { params(path: String, content_type: String).void }
        def initialize(path, content_type)
          @path = path
          @content_type = content_type
        end
      end

      sig { void }
      def initialize
        @assets = T.let({}, T::Hash[String, Asset])
      end

      sig { params(path: String, content_type: String).void }
      def add(path, content_type)
        @assets[path] = Asset.new(path, content_type)
      end

      sig { params(path: String) }
      def remove(path, content_type)
      end
    end
  end
end
