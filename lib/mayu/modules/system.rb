# typed: strict

require_relative "component_module"
require_relative "css"

module Mayu
  module Modules
    class System
      extend T::Sig

      class ResolveError < StandardError ; end

      ModuleType = T.type_alias { T.any(ComponentModule, CSS::Base) }

      sig { params(root: String).void }
      def initialize(root)
        @root = T.let(File.expand_path(root), String)
        @modules = T.let({}, T::Hash[String, ModuleType])
      end

      sig { params(path: String, source_path: String).returns(ComponentModule) }
      def load_page(path, source_path = "/")
        resolve_path('app', path, source_path) => [full_path, resolved_path]
        p [:load_page, path, resolved_path, full_path]

        T.cast(@modules[resolved_path] ||= ComponentModule.new(
          self,
          resolved_path,
          full_path,
          File.read(full_path)
        ), Mayu::Modules::ComponentModule)
      end

      sig { params(path: String, source_path: String).returns(ComponentModule) }
      def load_component(path, source_path = "/")
        resolve_path('components', path, source_path) => [full_path, resolved_path]

        T.cast(@modules[resolved_path] ||= ComponentModule.new(
          self,
          resolved_path,
          full_path,
          File.read(full_path)
        ), Mayu::Modules::ComponentModule)
      end

      sig { params(subdir: String, path: String, source_path: String).returns([String, String]) }
      def resolve_path(subdir, path, source_path = "/")
        resolved_path = File.expand_path(path, File.dirname(source_path)).sub(/(\.mayu)?$/, ".mayu")
        full_path = File.join(@root, subdir, resolved_path)

        if File.file?(full_path)
          [full_path, resolved_path]
        else
          raise ResolveError,
            "Could not find #{full_path} in #{@root}"
        end
      end

      sig { params(path: String).returns(CSS::Base) }
      def load_css(path)
        # CSS files are always together with their components,
        # just replace the extension.
        CSS.load(path.sub(/\.mayu$/, ".css"))
      end
    end
  end
end
