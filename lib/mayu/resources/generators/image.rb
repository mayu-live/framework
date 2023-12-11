# frozen_string_literal: true
# typed: strict

require "image_size"
require "base64"
require "shellwords"
require_relative "base"

module Mayu
  module Resources
    module Generators
      class Image < Base
        extend T::Sig

        sig do
          params(
            source_path: String,
            version: Types::Image::ImageDescriptor
          ).void
        end
        def initialize(source_path, version)
          @source_path = source_path
          @version = version
        end

        sig { override.params(target_path: String).void }
        def process(target_path)
          return if File.exist?(target_path)

          require "rmagick"

          Console.logger.info(
            self,
            "Generating #{target_path} from #{@source_path}"
          )

          Magick::Image
            .read(@source_path)
            .first
            .resize_to_fit(@version.width)
            .write(target_path) { |options| options.quality = 80 }
        end
      end
    end
  end
end
