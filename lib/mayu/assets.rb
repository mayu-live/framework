# typed: strict

module Mayu
  module Assets
    # This is all temporary, needs to be thrown away and rewritten entirely.
    class Manager
      extend T::Sig

      sig { returns(T.attached_class) }
      def self.instance
        $mayu_assets_manager ||= new
      end

      sig { params(public_filename: String).returns(T.nilable(Asset)) }
      def self.find(public_filename)
        instance.find(public_filename)
      end

      sig { params(path: String, hash: String, content_type: String, content: String).void }
      def self.add(path, hash, content_type, content)
        instance.add(path, hash, content_type, content)
      end

      class Asset
        extend T::Sig

        sig { returns(String) }
        attr_reader :public_filename
        sig { returns(String) }
        attr_reader :content
        sig { returns(String) }
        attr_reader :content_type
        sig { returns(String) }
        attr_reader :hash

        sig do
          params(
            path: String,
            hash: String,
            content_type: String,
            content: String
          ).void
        end
        def initialize(path, hash, content_type, content)
          @path = path
          @hash = hash
          @content_type = content_type
          @content = content
          @public_filename = T.let(calculate_public_filename, String)
        end

        sig { returns(String) }
        def calculate_public_filename
          extname = File.extname(@path)
          hash + extname
        end
      end

      sig { void }
      def initialize
        @assets = T.let({}, T::Hash[String, Asset])
      end

      sig do
        params(
          path: String,
          hash: String,
          content_type: String,
          content: String
        ).void
      end
      def add(path, hash, content_type, content)
        @assets[hash] ||= Asset.new(path, hash, content_type, content)
      end

      sig { params(hash: String).void }
      def remove(hash)
        @assets.delete(hash)
      end

      sig { params(public_filename: String).returns(T.nilable(Asset)) }
      def find(public_filename)
        @assets.values.find { _1.public_filename == public_filename }
      end

      sig { params(paths: T::Array[String]).returns(T::Array[String]) }
      def public_filenames(paths)
        T.unsafe(@assets).values_at(*paths).compact.map(&:public_filename)
      end
    end
  end
end
