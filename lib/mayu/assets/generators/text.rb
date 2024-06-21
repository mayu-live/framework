# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Assets
    module Generators
      Text =
        Data.define(:filename, :content) do
          def process(assets_path)
            MIME::Types.type_for(filename).first => MIME::Type => mime_type

            encoded_content =
              Assets::EncodedContent.for_mime_type_and_content(
                mime_type,
                content
              )
            content_hash = Digest::SHA256.hexdigest(encoded_content.content)

            headers = {
              etag: Digest::SHA256.hexdigest(encoded_content.content),
              "content-type": mime_type.to_s,
              "content-length": encoded_content.content.bytesize,
              **encoded_content.headers
            }

            Assets::Asset[filename:, headers:, encoded_content:]
          end
        end
    end
  end
end
