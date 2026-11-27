# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
          :content,
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

            new(
              content_type:,
              content_hash:,
              content:,
              encoded_content:,
              filename:
            )
          end

          # What to send to a client with this accept-encoding header: the
          # compressed content if it can read it, the file as it is
          # otherwise.
          def representation(accept_encoding)
            encoding = encoded_content.encoding

            if encoding.nil? || StaticFiles.accepts?(encoding, accept_encoding)
              encoded_content
            else
              EncodedContent.none(content)
            end
          end

          # A file that can be sent in two ways says what the choice
          # depends on, so a cache keeps them apart.
          def headers(representation = encoded_content)
            {
              "content-type": content_type,
              **representation.headers,
              **(encoded_content.encoding ? {vary: "accept-encoding"} : {})
            }
          end
        end

      EncodedContent =
        Data.define(:encoding, :content) do
          def self.for_mime_type_and_content(mime_type, content) =
            if compressible?(mime_type)
              brotli(content)
            else
              none(content)
            end

          # Text, and JSON, which the source maps are.
          def self.compressible?(mime_type) =
            mime_type.media_type == "text" || mime_type.sub_type == "json"

          def self.none(content) = new(nil, content)

          def self.brotli(content) = new(:br, Brotli.deflate(content))

          def headers
            if encoding
              {"content-encoding": encoding.to_s}
            else
              {}
            end
          end
        end

      # Whether an accept-encoding header such as "gzip, br;q=0.8" allows a
      # content coding. A header that does not name the coding leaves it to
      # "*", and no header at all allows nothing but the file as it is.
      def self.accepts?(encoding, accept_encoding)
        qualities =
          Array(accept_encoding)
            .flat_map { it.to_s.split(",") }
            .to_h do |entry|
              coding, *parameters = entry.strip.downcase.split(/\s*;\s*/)
              quality = parameters.find { it.start_with?("q=") }
              [coding, quality ? quality.delete_prefix("q=").to_f : 1.0]
            end

        qualities.fetch(encoding.to_s) { qualities.fetch("*", 0.0) }.positive?
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
