# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  BREAKPOINTS = [120, 240, 320, 640, 768, 960, 1024, 1366, 1600, 1920, 3840]

  ImageVersion = Data.define(:filename, :width)

  Image =
    Data.define(:versions, :width, :height) do
      def public_path
        Kernel.format("/.mayu/assets/%s", versions.first.filename)
      end

      def to_s = public_path
      def src = public_path

      def sizes
        # TODO: https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement/sizes
        nil
      end

      def srcset
        # TOOD: https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement/srcset
        nil
      end

      def blur
        # TODO: Return a base64 encoded small blurred version
        nil
      end
    end
end
