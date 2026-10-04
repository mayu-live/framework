# frozen_string_literal: true

require "rmagick"

module Mayu
  module Build
    # Serves /favicon.ico from the app directory. A favicon.ico is used as it
    # is. Without one, a favicon.png is turned into an ICO with 16, 32 and 48
    # pixel images, skipping sizes larger than the source.
    #
    # The bytes go into the bundle, so the production server needs neither the
    # source files nor ImageMagick.
    module FaviconPlugin
      SPECIFIER = "virtual:mayu/favicon"
      ICO_FILENAME = "favicon.ico"
      PNG_FILENAME = "favicon.png"
      ICO_SIZES = [16, 32, 48].freeze

      def self.new(...)
        Plugin.new(...)
      end

      class Error < ::Klenod::Build::SourceError
        def initialize(error, module_id:)
          super(error, source: nil, module_id:)
        end

        def kind
          "Favicon error"
        end
      end

      class Plugin < ::Klenod::Build::Plugin
        def initialize
          @module_id = ::Klenod::Build::ModuleId.new("#{SPECIFIER}.rb", nil)
        end

        def resolve(dependency, _context)
          return nil unless dependency.specifier == SPECIFIER

          ::Klenod::Build::ResolvedDependency.new(dependency, @module_id, {virtual: true})
        end

        def load(module_id, context)
          return nil unless module_id.scheme == :virtual && module_id == @module_id

          bytes = favicon_bytes(context.source_dir)
          return "Default = nil\n" unless bytes

          <<~RUBY
            Default = {
              body: #{bytes.inspect}.b.freeze,
              etag: #{::Klenod::Build::Hashing.short(bytes).inspect}
            }.freeze
          RUBY
        end

        def transform(module_id, code, context)
          return super unless module_id.scheme == :virtual && module_id == @module_id

          ::Klenod::Build::TransformResult.new(code, [], nil, [], watched_patterns(module_id), {})
        end

        private

        def favicon_bytes(source_dir)
          ico_path = File.join(source_dir, ICO_FILENAME)
          return File.binread(ico_path) if File.file?(ico_path)

          png_path = File.join(source_dir, PNG_FILENAME)
          ico_from_png(png_path) if File.file?(png_path)
        end

        def ico_from_png(path)
          image = read_png(path)

          unless image.columns == image.rows
            raise error("#{PNG_FILENAME} is #{image.columns}x#{image.rows}, but a favicon must be square")
          end

          sizes = ICO_SIZES.select { it <= image.columns }
          sizes = [image.columns] if sizes.empty?

          list = Magick::ImageList.new
          sizes.each { |size| list << image.resize_to_fit(size, size) }
          list.to_blob { |info| info.format = "ICO" }
        ensure
          list&.each(&:destroy!)
          image&.destroy!
        end

        def read_png(path)
          image = Magick::Image.read(path).first
          return image if image

          raise error("ImageMagick could not identify #{PNG_FILENAME}")
        rescue Magick::ImageMagickError => e
          raise error(e)
        end

        def error(cause)
          Error.new(cause, module_id: ::Klenod::Build::ModuleId.new(PNG_FILENAME, nil))
        end

        def watched_patterns(module_id)
          [ICO_FILENAME, PNG_FILENAME].map do |filename|
            ::Klenod::Build::WatchedPattern.new(module_id, filename, :favicon, {})
          end
        end
      end
    end
  end
end
