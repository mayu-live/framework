# typed: strict
# frozen_string_literal: true

require_relative "errors"

module Mayu
  module Server
    class FileServer
      class FoundFile < T::Struct
        const :absolute_path, String
        const :content_type, String
        const :has_brotli, T::Boolean
      end

      CACHE_MAX_AGE = T.let(60 * 60 * 24 * 7, Integer)

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
        found_file = get_file(filename)

        headers = {
          "cache-control" => "public, max-age=#{CACHE_MAX_AGE}, immutable",
          "content-type" => found_file.content_type
        }

        if found_file.has_brotli && accept_encodings.include?("br")
          Protocol::HTTP::Response[
            200,
            { **headers, "content-encoding" => "br" },
            Protocol::HTTP::Body::File.open(found_file.absolute_path + ".br")
          ]
        else
          Protocol::HTTP::Response[
            200,
            headers,
            Protocol::HTTP::Body::File.open(found_file.absolute_path)
          ]
        end
      end

      private

      sig { params(filename: String).returns(FoundFile) }
      def get_file(filename)
        absolute_path = get_absolute_path(filename)

        @found_files[absolute_path] ||= find_file(absolute_path)
      end

      sig { params(absolute_path: String).returns(FoundFile) }
      def find_file(absolute_path)
        raise Errors::FileNotFound unless File.exist?(absolute_path)

        has_brotli = File.exist?(absolute_path + ".br")
        content_type = MIME::Types.type_for(absolute_path).first.to_s

        FoundFile.new(absolute_path:, has_brotli:, content_type:)
      end

      sig { params(filename: String).returns(String) }
      def get_absolute_path(filename)
        File.join(@root_dir, File.expand_path(filename, "/"))
      end
    end
  end
end
