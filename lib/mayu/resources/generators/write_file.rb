# frozen_string_literal: true
# typed: strict

require "fileutils"
require_relative "base"

module Mayu
  module Resources
    module Generators
      class WriteFile < Base
        extend T::Sig

        sig { params(contents: String, compress: T::Boolean).void }
        def initialize(contents:, compress:)
          @contents = contents
          @compress = compress
        end

        sig { override.params(target_path: String).void }
        def process(target_path)
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
