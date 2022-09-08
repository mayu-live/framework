# typed: strict

require_relative "system"

module Mayu
  module Resources
    class Resolver
      class ResolveError < StandardError
      end

      extend T::Sig

      sig { params(system: System).void }
      def initialize(system)
        @system = system
        @extensions = T.let(["", ".rb"], T::Array[String])
      end

      sig { params(path: String, source_dir: String).returns(String) }
      def resolve(path, source_dir = "/")
        # if path.start_with?("/")
        #   return resolve(".#{path}", "/")
        # end
        #
        # if !path.match(/\A\.\.?\//)
        #   return resolve("./#{path}", "/components")
        # end

        relative_to_root = File.absolute_path(path, source_dir)
        absolute_path = File.join(@system.root, relative_to_root)

        resolve_with_extensions(absolute_path) do |extension|
          return relative_to_root + extension
        end

        if File.directory?(absolute_path)
          basename = File.basename(absolute_path)

          resolve_with_extensions(
            File.join(absolute_path, basename)
          ) do |extension|
            return File.join(relative_to_root, basename) + extension
          end
        end

        raise ResolveError, "Could not resolve #{path} from #{source_dir}"
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

          yield extension if File.file?(absolute_path + extension)
        end
      end
    end
  end
end
