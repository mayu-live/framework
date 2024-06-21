# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "brotli"

module Mayu
  module Assets
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
  end
end
