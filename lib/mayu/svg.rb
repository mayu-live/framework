# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  SVG =
    Data.define(:filename, :width, :height) do
      def public_path
        File.join("/.mayu/assets", filename)
      end

      def to_s = public_path
      def src = public_path
    end
end
