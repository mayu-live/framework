# frozen_string_literal: true
# typed: strict

require "image_size"
require "base64"
require_relative "base"

module Mayu
  module Resources
    module Types
      class Image < Base
        extend T::Sig

        BREAKPOINTS =
          T.let(
            [640, 768, 960, 1024, 1366, 1600, 1920, 3840].freeze,
            T::Array[Integer]
          )

        class ImageDescriptor < T::Struct
          const :format, Symbol
          const :width, Integer
          const :height, Integer
          const :filename, String
        end

        sig { returns(ImageDescriptor) }
        attr_reader :original
        sig { returns(T::Array[ImageDescriptor]) }
        attr_reader :versions

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource

          content_hash = Base64.urlsafe_encode64(resource.content_hash)
          image_size = ImageSize.path(resource.absolute_path)

          extname = File.extname(resource.path)
          filename = "#{content_hash}#{extname}"

          @original =
            T.let(
              ImageDescriptor.new(
                format: image_size.format,
                width: image_size.width,
                height: image_size.height,
                filename: filename
              ),
              ImageDescriptor
            )

          breakpoints =
            BREAKPOINTS.select { _1 < image_size.width }.sort.reverse
          aspect_ratio = image_size.height / image_size.width.to_f

          @versions =
            T.let(
              breakpoints.map do |width|
                ImageDescriptor.new(
                  format: image_size.format,
                  width:,
                  height: (width * aspect_ratio).to_i,
                  filename: "#{content_hash}#{width}w#{extname}"
                )
              end,
              T::Array[ImageDescriptor]
            )
        end

        sig { params(asset_dir: String).void }
        def generate_assets(asset_dir)
          path = File.join(asset_dir, @original.filename)

          unless File.exist?(path)
            puts "\e[35mCreating #{path} from copy\e[0m"
            FileUtils.copy_file(@resource.absolute_path, path)
          end

          @versions.reduce(path) do |previous_path, version|
            path = File.join(asset_dir, version.filename)
            next path if File.exist?(path)
            puts "\e[35mGenerating #{path}\e[0m"
            system(
              "convert",
              previous_path,
              "-adaptive-resize",
              "#{version.width}",
              path
            )
            path
          end
        end

        MarshalFormat =
          T.type_alias { [ImageDescriptor, T::Array[ImageDescriptor]] }

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@original, @versions]
        end

        sig { params(args: MarshalFormat).void }
        def marshal_load(args)
          @original, @versions = args
        end
      end
    end
  end
end
