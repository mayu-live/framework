# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "mime/types"
require "brotli"
require "digest/sha2"
require "base64"

MIME::Types["application/json"].first.add_extensions(%w[map])

module Mayu
  module Modules
    class Assets
      Asset =
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
                File.basename(filename, ".*"),
                mime_type.preferred_extension,
                Base64.urlsafe_encode64(content_hash, padding: false)[0..10]
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
            encoding ? { "content-encoding": encoding.to_s } : {}
          end
        end

      def initialize
        @assets = {}
      end

      def get(filename)
        @assets.fetch(filename) do
          puts "\e[91;1mAsset not found: \e[0;31m#{filename}\e[0m"
          nil
        end
      end

      def store(asset)
        puts "\e[34mStoring asset: #{asset.filename}\e[0m"
        @assets.store(asset.filename, asset)
      end
    end
  end
end
