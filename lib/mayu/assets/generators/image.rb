# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Assets
    module Generators
      Image =
        Data.define(:filename, :source_path, :width) do
          def process(out_dir)
            target_path = File.join(out_dir, filename)

            unless File.exist?(target_path)
              require "rmagick"

              Console.logger.info(
                self,
                "Generating #{target_path} from #{source_path}"
              )

              r =
                Ractor.new(self, target_path) do |generator, target_path|
                  Magick::Image
                    .read(generator.source_path)
                    .first
                    .resize_to_fit!(generator.width)
                    .write(target_path) { |options| options.quality = 80 }
                    .destroy!
                  nil
                end

              r.take
            end

            build_asset(filename)
          rescue => e
            Console.logger(self, e)
            raise
          end

          private

          def build_asset(filename)
            MIME::Types.type_for(filename).first => MIME::Type => mime_type

            headers = { content_type: mime_type.to_s }

            Assets::Asset[
              filename:,
              headers:,
              encoded_content: Assets::FileContent.new
            ]
          end
        end
    end
  end
end
