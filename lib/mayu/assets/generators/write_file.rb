# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Assets
    module Generators
      WriteFile =
        Data.define(:filename, :source_path) do
          def process(assets_path)
            target_path = File.join(assets_path, filename)

            unless File.exist?(target_path)
              Console.logger.info(
                self,
                "Copying #{target_path} from #{source_path}"
              )

              FileUtils.mkdir_p(File.dirname(target_path))
              FileUtils.cp(source_path, target_path)
            end

            build_asset(filename)
          end

          private

          def build_asset(filename)
            filename_without_hash = filename.sub(/\?[^?]*$/, "")

            MIME::Types.type_for(filename_without_hash).first =>
              MIME::Type => mime_type

            headers = {
              etag: Digest::SHA256.file(source_path).hexdigest,
              "content-type": mime_type.to_s,
              "content-length": File.size(source_path)
            }

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
