# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  StyleSheet =
    Data.define(:source_filename, :content_hash, :classes, :content) do
      def self.encode_url(url)
        url
      end

      def filename
        source_filename + ".css"
      end
    end
end
