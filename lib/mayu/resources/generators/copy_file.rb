# frozen_string_literal: true
# typed: strict

require "fileutils"
require_relative "base"

module Mayu
  module Resources
    module Generators
      class CopyFile < Base
        extend T::Sig

        sig { params(source_path: String).void }
        def initialize(source_path)
          @source_path = source_path
        end

        sig { override.params(target_path: String).void }
        def process(target_path)
          return if File.exist?(target_path)
          FileUtils.copy_file(@source_path, target_path)
        end
      end
    end
  end
end
