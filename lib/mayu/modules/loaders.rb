module Mayu
  module Modules
    module Loaders
      LoadingFile = Data.define(:root, :path, :source, :digest) do
        def self.[](root, path, source = nil, digest = nil)
          new(root, path, source, digest)
        end

        def with_digest
          digest ? self : with(digest: Digest::SHA256.file(absolute_path).digest)
        end

        def absolute_path
          File.join(root, path)
        end

        def transform(&)
          with(source: yield(self))
        end

        def maybe_load_source
          source ? self : load_source
        end

        def load_source
          with(source: File.read(absolute_path))
        end
      end

      autoload :CSS, File.join(__dir__, "loaders", "css")
      autoload :Haml, File.join(__dir__, "loaders", "haml")
      autoload :Image, File.join(__dir__, "loaders", "image")
      autoload :JavaScript, File.join(__dir__, "loaders", "java_script")
      autoload :Ruby, File.join(__dir__, "loaders", "ruby")
    end
  end
end
