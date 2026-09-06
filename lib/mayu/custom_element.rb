# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  CustomElement =
    Data.define(:name, :asset_path) do
      def self.from_klenod(descriptor)
        unless descriptor.is_a?(Hash) && descriptor[:__klenod_custom_element]
          return nil
        end

        new(descriptor.fetch(:tag), descriptor.fetch(:asset_path))
      end

      def path
        return asset_path if asset_path.start_with?("/", "http://", "https://")

        "/.mayu/assets/#{asset_path}"
      end
    end
end
