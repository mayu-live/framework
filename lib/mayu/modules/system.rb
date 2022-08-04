# typed: strict

require_relative "component_module"
require_relative "css"

module Mayu
  module Modules
    class System
      extend T::Sig

      ModuleType = T.type_alias { T.any(ComponentModule, CSS::Base) }

      sig { returns(String) }
      attr_reader :app_root
      sig { returns(String) }
      attr_reader :components_root

      sig { params(root: String).void }
      def initialize(root)
        @app_root = T.let(File.join(root, 'app'), String)
        @components_root = T.let(File.join(root, 'components'), String)
        p "COMPONENTS ROOT, #{@components_root}"
        @modules = T.let({}, T::Hash[String, ModuleType])
      end

      sig { params(path: String, source_path: String).returns(ComponentModule) }
      def load_page(path, source_path = "/")
        resolved_path = resolve_path(@app_root, path, source_path)
        p [:load_page, path, resolved_path]

        T.cast(@modules[resolved_path] ||= ComponentModule.new(
          self,
          resolved_path,
          File.read(File.join(@app_root, resolved_path))
        ), Mayu::Modules::ComponentModule)
      end

      sig { params(path: String, source_path: String).returns(ComponentModule) }
      def load_component(path, source_path = "/")
        resolved_path = resolve_path(@components_root, path, source_path)

        T.cast(@modules[resolved_path] ||= ComponentModule.new(
          self,
          resolved_path,
          File.read(File.join(@components_root, resolved_path))
        ), Mayu::Modules::ComponentModule)
      end

      sig { params(root: String, path: String, source_path: String).returns(String) }
      def resolve_path(root, path, source_path = "/")
        full_path = File.expand_path(path, File.dirname(source_path))

        if File.file?(File.join(root, full_path))
          full_path
        else
          full_path.sub(/(.mayu)?$/, ".mayu")
        end
      end

      sig { params(path: String).returns(CSS::Base) }
      def load_css(path)
        resolved_path = resolve_path(@components_root, path).sub(/\.mayu$/, ".css")
        CSS.load(File.join(@components_root, resolved_path))
      end
    end
  end
end
