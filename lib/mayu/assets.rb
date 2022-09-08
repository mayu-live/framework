# typed: strict

require "async/variable"

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

      sig do
        params(
          path: String,
          hash: String,
          content_type: String,
          content: String
        ).void
      end
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

    module Sources
      class Base
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { abstract.params(root: String, outdir: String).returns(String) }
        def generate(root:, outdir:)
        end
      end

      class File < Base
        sig { params(path: String).void }
        def initialize(path:)
          @path = path
          @mime_type = T.let(MIME::Types.of(@path).first, MIME::Type)
        end

        sig { override.params(root: String, outdir: String).returns(String) }
        def generate(root:, outdir:)
          source = ::File.join(root, @path)
          content = ::File.read(source)
          hash = Digest::SHA256.hexdigest(content)
          extension = @mime_type.preferred_extension
          target = ::File.join(outdir, "#{hash}.#{extension}")
          ::File.write(target, content)
          target
        end
      end

      class Content < Base
        sig { params(content_type: String, content: String).void }
        def initialize(content_type:, content:)
          p content_type
          @mime_type = T.let(MIME::Types[content_type].first, MIME::Type)
          @content = content
        end

        sig { override.params(root: String, outdir: String).returns(String) }
        def generate(root:, outdir:)
          hash = Digest::SHA256.hexdigest(@content)
          extension = @mime_type.preferred_extension
          target = ::File.join(outdir, "#{hash}.#{extension}")
          ::File.write(target, @content)
          target
        end
      end
    end

    class Asset
      extend T::Sig

      sig do
        params(content_type: String, content: String).returns(T.attached_class)
      end
      def self.from_content(content_type:, content:)
        new(Sources::Content.new(content_type:, content:))
      end

      sig { params(path: String).returns(T.attached_class) }
      def self.from_file(path:)
        new(Sources::File.new(path:))
      end

      sig { returns(Sources::Base) }
      attr_reader :source

      sig { params(source: Sources::Base).void }
      def initialize(source)
        @source = source
        @filename = T.let(Async::Variable.new, Async::Variable)
      end

      sig { params(root: String, outdir: String).void }
      def generate(root:, outdir:)
        return if @filename.resolved?
        filename = @source.generate(root:, outdir:)
        @filename.resolve(filename)
        Console.logger.info("Generated asset #{filename}")
      end

      sig { returns(String) }
      def filename
        @filename.value
      end
    end
  end
end
