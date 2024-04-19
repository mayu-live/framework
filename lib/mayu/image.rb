# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  Image =
    Data.define(:path, :format, :digest, :width, :height) do
      def public_path
        Kernel.format(
          "/.mayu/assets/%s.%s?%s",
          File.basename(path, ".*"),
          format,
          digest
        )
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
