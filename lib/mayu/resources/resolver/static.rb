# frozen_string_literal: true
# typed: strict

require_relative "base"

module Mayu
  module Resources
    module Resolver
      class Static < Base
        sig { params(paths: T::Hash[String, String]).void }
        def initialize(paths)
          super()
          @resolved_paths = paths
          # Console.logger.info(self, *@resolved_paths.map { "#{_1} => #{_2}" })
        end

        sig do
          override.params(path: String, source_dir: String).returns(String)
        end
        def resolve(path, source_dir = "/")
          relative_to_root = File.absolute_path(path, source_dir)
          @resolved_paths[relative_to_root] || relative_to_root
        end
      end
    end
  end
end
