# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "mime/types"
require "brotli"
require "digest/sha2"
require "base64"
require "async/queue"
require "async/variable"
require "async/semaphore"

MIME::Types["application/json"].first.add_extensions(%w[map])

module Mayu
  module Modules
    module Assets
      Asset = Data.define(:filename, :headers, :encoded_content)

      FileContent = Data.define

      EncodedContent =
        Data.define(:encoding, :content) do
          def self.for_mime_type_and_content(mime_type, content) =
            if mime_type.media_type == "text"
              brotli(content)
            else
              none(content)
            end

          def self.none(content) = new(nil, content)

          def self.brotli(content) = new(:br, Brotli.deflate(content))

          def headers
            encoding ? { "content-encoding": encoding.to_s } : {}
          end
        end

      module Generators
        Image =
          Data.define(:filename, :source_path, :width) do
            def process(assets_path)
              require "rmagick"

              target_path = File.join(assets_path, filename)

              Console.logger.info(
                self,
                "Generating #{target_path} from #{source_path}"
              )

              Magick::Image
                .read(source_path)
                .first
                .resize_to_fit(width)
                .write(target_path) { |options| options.quality = 80 }

              headers = { content_type: mime_type.to_s }

              Assets::Asset.build(
                filename:,
                headers:,
                encoded_content: FileContent.new
              )
            end
          end

        Text =
          Data.define(:filename, :content) do
            def process(assets_path)
              MIME::Types.type_for(filename).first => MIME::Type => mime_type

              encoded_content =
                EncodedContent.for_mime_type_and_content(mime_type, content)
              content_hash = Digest::SHA256.hexdigest(encoded_content.content)

              headers = {
                etag: Digest::SHA256.hexdigest(encoded_content.content),
                "content-type": mime_type.to_s,
                "content-length": encoded_content.content.bytesize,
                **encoded_content.headers
              }

              Asset[filename:, headers:, encoded_content:]
            end
          end
      end

      class Storage
        def initialize
          @assets = {}
          @results = {}
          @queue = Async::Queue.new
        end

        def get(filename)
          puts "Getting #{filename}"
          @assets[filename]
        end

        def wait_for(filename)
          @assets.fetch(filename) do
            (@results[filename] ||= Async::Variable.new).wait
          end
        end

        def enqueue(generator)
          @queue.enqueue(generator)
        end

        def all_processed?
          @queue.empty?
        end

        def run(
          assets_dir,
          forever: false,
          concurrency: 1,
          task: Async::Task.current
        )
          task.async do
            semaphore = Async::Semaphore.new(concurrency)

            while forever || !@queue.empty?
              generator = @queue.dequeue

              semaphore.async { process(generator, assets_dir) }
            end
          end
        end

        private

        def process(generator, assets_dir)
          puts "Processing #{generator.filename}"
          if asset = generator.process(assets_dir)
            @assets.store(asset.filename, asset)
            var = (@results[asset.filename] ||= Async::Variable.new)
            var.resolve(asset) unless var.resolved?
            @results.delete(asset.filename)
          end
        rescue => e
          Console.logger.error(self, e)
          raise e
        end
      end
    end
  end
end
