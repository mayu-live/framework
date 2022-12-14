# typed: strict
# frozen_string_literal: true

require_relative "errors"

module Mayu
  module Server
    class FileServer
      class FoundFile < T::Struct
        const :absolute_path, String
        const :content_type, String
        const :size, Integer
      end

      # TODO: Make configurable. A higher value means less
      # filsystem IO, but obviously consumes more memory.
      DEFAULT_MEMORY_CACHE_MAX_SIZE = T.let(1024, Integer)

      CACHE_MAX_AGE = T.let(60 * 60 * 24 * 7, Integer)

      CACHE_CONTROL =
        T.let(
          {
            "cache-control" => "public, max-age=#{CACHE_MAX_AGE}, immutable"
          }.freeze,
          T::Hash[String, String]
        )
      BROTLI_CONTENT_ENCODING =
        T.let({ "content-encoding" => "br" }.freeze, T::Hash[String, String])

      extend T::Sig

      sig { params(root_dir: String, memory_cache_max_size: Integer).void }
      def initialize(
        root_dir,
        memory_cache_max_size: DEFAULT_MEMORY_CACHE_MAX_SIZE
      )
        @root_dir = root_dir
        @found_files =
          T.let(
            T::Hash[String, FoundFile].new do |h, filename|
              if found_file = find_file(filename)
                h[filename] = found_file
              end
            end,
            T::Hash[String, FoundFile]
          )
        @memory_cache_max_size = memory_cache_max_size
        @memory_cache = T.let({}, T::Hash[String, String])
      end

      sig do
        params(filename: String, accept_encodings: T::Array[String]).returns(
          Protocol::HTTP::Response
        )
      end
      def serve(filename, accept_encodings: [])
        found_file = @found_files[filename]

        unless found_file
          raise Errors::FileNotFound, "Could not find file #{filename}"
        end

        headers = {
          **CACHE_CONTROL,
          "content-type" => add_charset(found_file.content_type)
        }

        if accept_encodings.include?("br")
          if brotlied = @found_files["#{filename}.br"]
            return(
              Protocol::HTTP::Response[
                200,
                { **headers, **BROTLI_CONTENT_ENCODING },
                read_file(brotlied)
              ]
            )
          end
        end

        contents = read_file(found_file)
        Protocol::HTTP::Response[200, headers, read_file(found_file)]
      end

      private

      sig { params(filename: String).returns(T.nilable(FoundFile)) }
      def find_file(filename)
        absolute_path = File.join(@root_dir, filename)

        return unless File.exist?(absolute_path)

        size = File.size(absolute_path)

        content_type =
          MIME::Types.type_for(absolute_path.delete_suffix(".br")).first.to_s

        FoundFile.new(absolute_path:, content_type:, size:)
      end

      sig do
        params(found_file: FoundFile).returns(
          T.any([String], Protocol::HTTP::Body::File)
        )
      end
      def read_file(found_file)
        if found_file.size > @memory_cache_max_size
          return Protocol::HTTP::Body::File.open(found_file.absolute_path)
        end

        [
          @memory_cache[found_file.absolute_path] ||= begin
            File.read(found_file.absolute_path)
          end
        ]
      end

      sig { params(filename: String).returns(String) }
      def get_absolute_path(filename)
        File.join(@root_dir, File.expand_path(filename, "/"))
      end

      sig { params(content_type: String).returns(String) }
      def add_charset(content_type)
        if add_charset?(content_type)
          "#{content_type}; charset=utf-8"
        else
          content_type
        end
      end

      sig { params(content_type: String).returns(T::Boolean) }
      def add_charset?(content_type)
        content_type in
          "application/javascript" | "application/json" | "image/svg+xml" |
            "text/css" | "text/html"
      end
    end
  end
end
