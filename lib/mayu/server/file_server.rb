# typed: strict
# frozen_string_literal: true

module Mayu
  module Server
    class FileServer
      class FoundFile < T::Struct
        const :absolute_path, String
        const :content_type, String
        const :has_brotli, T::Boolean
      end

      extend T::Sig

      sig { params(root_dir: String).void }
      def initialize(root_dir)
        @root_dir = root_dir
        @found_files = T.let({}, T::Hash[String, FoundFile])
      end

      sig do
        params(filename: String, accept_encodings: T::Array[String]).returns(
          Protocol::HTTP::Response
        )
      end
      def serve(filename, accept_encodings: [])
        if found_file = find_file(filename)
          make_response(found_file, accept_encodings:)
        else
          Protocol::HTTP::Response[404, {}, ["not found"]]
        end
      end

      private

      sig { params(filename: String).returns(T.nilable(FoundFile)) }
      def find_file(filename)
        absolute_path = get_absolute_path(filename)

        @found_files[absolute_path] ||= begin
          return nil unless File.exist?(absolute_path)

          has_brotli = File.exist?(absolute_path + ".br")
          content_type = MIME::Types.type_for(filename).first.to_s

          FoundFile.new(absolute_path:, has_brotli:, content_type:)
        end
      end

      sig do
        params(
          found_file: FoundFile,
          accept_encodings: T::Array[String]
        ).returns(Protocol::HTTP::Response)
      end
      def make_response(found_file, accept_encodings:)
        if accept_encodings.include?("br") && found_file.has_brotli
          Protocol::HTTP::Response[
            200,
            {
              "content-type" => found_file.content_type,
              "content-encoding" => "br"
            },
            Protocol::HTTP::Body::File.open(found_file.absolute_path + ".br")
          ]
        else
          Protocol::HTTP::Response[
            200,
            { "content-type" => found_file.content_type },
            Protocol::HTTP::Body::File.open(found_file.absolute_path)
          ]
        end
      end

      sig { params(filename: String).returns(String) }
      def get_absolute_path(filename)
        File.join(@root_dir, File.expand_path(filename, "/"))
      end
    end
  end
end
