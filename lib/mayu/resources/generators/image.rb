# frozen_string_literal: true
# typed: strict

require "image_size"
require "base64"
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

        sig { override.params(asset_dir: String).void }
        def process(asset_dir)
          target_path = File.join(asset_dir, @version.filename)
          return if File.exist?(target_path)

          case @version.format
          when :webp
            convert_webp(
              source_path: @source_path,
              quality: 80, # typical quality,
              width: @version.width,
              target_path: target_path
            )
          else
            convert_generic(
              source_path: @source_path,
              quality: 80, # typical quality,
              width: @version.width,
              target_path: target_path
            )
          end
        end

        private

        sig do
          params(
            source_path: String,
            quality: Integer,
            width: Integer,
            target_path: String
          ).void
        end
        def convert_webp(source_path:, quality:, width:, target_path:)
          system(
            "cwebp",
            "-q",
            "#{quality}",
            "-resize",
            "#{width}",
            "0",
            source_path,
            "-o",
            target_path
          )
        end

        sig do
          params(
            source_path: String,
            quality: Integer,
            width: Integer,
            target_path: String
          ).void
        end
        def convert_generic(source_path:, quality:, width:, target_path:)
          system(
            "convert",
            source_path,
            "-adaptive-resize",
            "#{width}",
            "-strip",
            target_path
          )
        end
      end
    end
  end
end
