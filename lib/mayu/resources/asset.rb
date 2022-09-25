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
        Console.logger.info(self, "Writing #{@filename}")
        File.write(File.join(path, @filename), content)

        if compress
          Console.logger.info(self, "Compressing #{@filename}")
          File.write(
            File.join(path, @filename + ".br"),
            Brotli.deflate(content)
          )
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
