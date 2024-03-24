module Mayu
  module Modules
    class Resolver
      class ResolveError < StandardError
      end

      attr_reader :root

      def initialize(root, extensions: [], verbose: false)
        @root = root
        @extensions = extensions
        @verbose = verbose
        @resolved_paths = {}
      end

      def resolve(path, source_dir = "/")
        relative_to_root = File.absolute_path(path, source_dir)

        @resolved_paths.fetch(relative_to_root) do
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
      end

      private

      def resolve_with_extensions(absolute_path, &block)
        @extensions.find do |extension|
          absolute_path_with_extension = absolute_path + extension

          if File.file?(absolute_path_with_extension)
            $stderr.puts "\e[1mFound #{absolute_path_with_extension}\e[0m" if @verbose
            yield extension
          else
            $stderr.puts "\e[2mTried #{absolute_path_with_extension}\e[0m" if @verbose
          end
        end
      end
    end
  end
end
