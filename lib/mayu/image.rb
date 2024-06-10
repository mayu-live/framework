# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  BREAKPOINTS = [120, 240, 320, 640, 768, 960, 1024, 1366, 1600, 1920, 3840]

  ImageVersion =
    Data.define(:filename, :width) do
      def public_path
        Kernel.format("/.mayu/assets/%s", filename)
      end
    end

  Image =
    Data.define(:versions, :width, :height, :blur_src) do
      def public_path = versions.first.public_path

      def to_s = public_path
      def src = public_path
      def blur_url = "url(#{blur_src})"

      def sizes
        # TODO: https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement/sizes
        nil
      end

      def srcset
        versions.map { |v| "#{v.public_path} #{v.width}w" }.join(",")
      end
    end
end
