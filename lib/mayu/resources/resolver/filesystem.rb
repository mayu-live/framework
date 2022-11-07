# frozen_string_literal: true
# typed: strict

require_relative "base"

module Mayu
  module Resources
    module Resolver
      class Filesystem < Base
        sig { params(root: String, extensions: T::Array[String]).void }
        def initialize(root, extensions: [""])
          super()
          @root = root
          @extensions = extensions
        end

        sig do
          override.params(path: String, source_dir: String).returns(String)
        end
        def resolve(path, source_dir = "/")
          # TODO: Fix this!!
          # if path.start_with?("/")
          #   return resolve(".#{path}", "/")
          # end
          #
          # if !path.match(/\A\.\.?\//)
          #   return resolve("./#{path}", "/components")
          # end

          relative_to_root = File.absolute_path(path, source_dir)

          if found = @resolved_paths[relative_to_root]
            return found
          end

          absolute_path = File.join(@root, relative_to_root)

          resolve_with_extensions(absolute_path) do |extension|
            return(
              @resolved_paths.store(
                relative_to_root,
                relative_to_root + extension
              )
            )
          end

          if File.directory?(absolute_path)
            basename = File.basename(absolute_path)

            resolve_with_extensions(
              File.join(absolute_path, basename)
            ) do |extension|
              return(
                @resolved_paths.store(
                  relative_to_root,
                  File.join(relative_to_root, basename) + extension
                )
              )
            end
          end

          raise ResolveError,
                "Could not resolve #{path} from #{source_dir} (app root: #{@root})"
        end

        private

        sig do
          params(
            absolute_path: String,
            block: T.proc.params(arg0: String).void
          ).void
        end
        def resolve_with_extensions(absolute_path, &block)
          @extensions.find do |extension|
            absolute_path_with_extension = absolute_path + extension

            if File.file?(absolute_path_with_extension)
              puts "\e[1mFound #{absolute_path_with_extension}\e[0m"
              yield extension
            else
              puts "\e[2mTried #{absolute_path_with_extension}\e[0m"
            end
          end
        end

        sig { params(path: String).returns(T::Boolean) }
        def exist?(path)
          File.exist?(path)
        end
      end
    end
  end
end
