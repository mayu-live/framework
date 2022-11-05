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

        FORMATS = T.let([:webp], T::Array[Symbol])

        BREAKPOINTS =
          T.let(
            [120, 240, 320, 640, 768, 960, 1024, 1366, 1600, 1920, 3840].freeze,
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
        sig { returns(String) }
        attr_reader :blur

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource

          content_hash = Base64.urlsafe_encode64(resource.content_hash)
          image_size = ImageSize.path(resource.absolute_path)

          extname = File.extname(resource.path)
          filename = "#{content_hash}.#{image_size.format}"

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

          formats = [image_size.format, *FORMATS].uniq

          @blur =
            T.let(
              [
                "convert",
                resource.absolute_path,
                "-resize",
                "16x16>",
                "-strip",
                "png:-"
              ].then { Shellwords.shelljoin(_1) }
                .then { `#{_1}` }
                .then { Base64.strict_encode64(_1) }
                .prepend("data:image/png;base64,"),
              String
            )

          @versions =
            T.let(
              formats
                .map do |format|
                  breakpoints.map do |width|
                    ImageDescriptor.new(
                      format: format,
                      width:,
                      height: (width * aspect_ratio).to_i,
                      filename: "#{content_hash}#{width}w.#{format}"
                    )
                  end
                end
                .flatten,
              T::Array[ImageDescriptor]
            )
        end

        sig { returns(T::Array[Asset]) }
        def assets
          [
            Asset.new(
              @original.filename,
              Generators::CopyFile.new(
                @resource.absolute_path,
                @original.filename
              )
            ),
            *@versions.map do |version|
              Asset.new(
                version.filename,
                Generators::Image.new(@resource.absolute_path, version)
              )
            end
          ]
        end

        sig { params(asset_dir: String).returns(T::Array[Asset]) }
        def generate_assets(asset_dir)
          assets.each { |asset| asset.process(asset_dir) }
        end

        sig { returns(String) }
        def src
          "/__mayu/static/#{@original.filename}"
        end

        sig { returns(String) }
        def srcset
          [@original, *@versions.filter { _1.format == :webp }].map do |version|
              "/__mayu/static/#{version.filename} #{version.width}w"
            end
            .reverse
            .join(",")
        end

        sig { returns(String) }
        def sizes
          [
            "100vw",
            *@versions
              .filter { _1.format == :webp }
              .map do |version|
                "(max-width: #{version.width}px) #{version.width}px"
              end
          ].reverse.join(", ")
        end

        sig { returns(Float) }
        def aspect_ratio
          original.width / original.height.to_f
        end

        MarshalFormat =
          T.type_alias { [ImageDescriptor, T::Array[ImageDescriptor], String] }

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@original, @versions, @blur]
        end

        sig { params(args: MarshalFormat).void }
        def marshal_load(args)
          @original, @versions, @blur = args
        end

        sig { returns(String) }
        def inspect
          "#<Image src=#{src.inspect}>"
        end
      end
    end
  end
end
