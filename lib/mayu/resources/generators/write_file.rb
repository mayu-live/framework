# frozen_string_literal: true
# typed: strict

require "fileutils"
require_relative "base"

module Mayu
  module Resources
    module Generators
      class WriteFile < Base
        extend T::Sig

        sig do
          params(filename: String, contents: String, compress: T::Boolean).void
        end
        def initialize(filename:, contents:, compress:)
          @filename = filename
          @contents = contents
          @compress = compress
        end

        sig { override.params(asset_dir: String).void }
        def process(asset_dir)
          target_path = File.join(asset_dir, @filename)

          write_file(target_path, @contents)

          if @compress
            write_file(target_path + ".br", Brotli.deflate(@contents))
          end
        end

        private

        sig { params(path: String, content: String).void }
        def write_file(path, content)
          return if File.exist?(path)
          Console.logger.info(self, "Writing #{path}")
          File.write(path, content)
        end
      end
    end
  end
end
