# frozen_string_literal: true
# typed: strict

module Mayu
  module Resources
    class Asset
      extend T::Sig

      sig { returns(String) }
      attr_reader :filename

      sig { params(filename: String).void }
      def initialize(filename)
        @filename = filename
      end

      sig { params(path: String, content: String, compress: T::Boolean).void }
      def generate(path, content, compress: false)
        file_path = File.join(path, @filename)

        unless File.exists?(file_path)
          Console.logger.info(self, "Writing #{@filename}")
          File.write(file_path, content)
        end

        return unless compress

        file_path += ".br"

        unless File.exists?(file_path)
          Console.logger.info(self, "Compressing #{@filename}")
          File.write(file_path, Brotli.deflate(content))
        end
      end

      MarshalFormat = T.type_alias { [String] }

      sig { returns(MarshalFormat) }
      def marshal_dump
        [@filename]
      end

      sig { params(args: MarshalFormat).void }
      def marshal_load(args)
        @filename = args.first
      end
    end
  end
end
