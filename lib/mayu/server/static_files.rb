# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "mime/types"
require "brotli"
require "digest/sha2"
require "base64"

MIME::Types["application/json"].first.add_extensions(%w[map])

module Mayu
  class Server
    class StaticFiles
      StaticFile =
        Data.define(
          :content_type,
          :content_hash,
          :encoded_content,
          :filename
        ) do
          def self.build(filename, content)
            MIME::Types.type_for(filename).first => MIME::Type => mime_type

            encoded_content =
              EncodedContent.for_mime_type_and_content(mime_type, content)
            content_hash = Digest::SHA256.digest(encoded_content.content)
            content_type = mime_type.to_s

            filename =
              format(
                "%s.%s?%s",
                File.join(
                  File.dirname(filename),
                  File.basename(filename, ".*")
                ),
                mime_type.preferred_extension,
                Base64.urlsafe_encode64(content_hash, padding: false)
              )

            new(content_type:, content_hash:, encoded_content:, filename:)
          end

          def headers
            {
              "content-type": content_type,
              "content-length": content_length,
              **encoded_content.headers
            }
          end

          def content_length
            encoded_content.content.bytesize
          end
        end

      EncodedContent =
        Data.define(:encoding, :content) do
          def self.for_mime_type_and_content(mime_type, content) =
            if mime_type.media_type == "text"
              brotli(content)
            else
              none(content)
            end

          def self.none(content) = new(nil, content)

          def self.brotli(content) = new(:br, Brotli.deflate(content))

          def headers
            if encoding
              { "content-encoding": encoding.to_s }
            else
              {}
            end
          end
        end

      def initialize(root)
        @root = File.expand_path(root)
        @files = {}
      end

      def get(path)
        clean_path = File.expand_path(path, "/")
        @files[clean_path] ||= read_file(clean_path)
      end

      private

      def read_file(path)
        full_path = File.join(@root, path)
        StaticFile.build(path, File.read(full_path))
      rescue Errno::ENOENT
        nil
      end
    end
  end
end
