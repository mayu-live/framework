# frozen_string_literal: true
# typed: strict

require "fileutils"
require_relative "base"

module Mayu
  module Resources
    module Generators
      class CopyFile < Base
        extend T::Sig

        sig { params(source_path: String, filename: String).void }
        def initialize(source_path, filename)
          @source_path = source_path
          @filename = filename
        end

        sig { override.params(asset_dir: String).void }
        def process(asset_dir)
          target_path = File.join(asset_dir, @filename)
          return if File.exist?(target_path)
          FileUtils.copy_file(@source_path, target_path)
        end
      end
    end
  end
end
