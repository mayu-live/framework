# typed: strict

require_relative "component_module"
require_relative "css_module"

module Mayu
  module Modules
    class System
      extend T::Sig

      ModuleType = T.type_alias { T.any(ComponentModule, CSS::Base) }

      sig { returns(String) }
      attr_reader :root

      sig { params(root: String).void }
      def initialize(root)
        @root = root
        @modules = T.let({}, T::Hash[String, ModuleType])
      end

      sig { params(path: String, source_path: String).returns(ComponentModule) }
      def load_component(path, source_path = "/")
        resolved_path = resolve_path(path, source_path)

        @modules[resolved_path] = ComponentModule.new(
          self,
          resolved_path,
          File.read(File.join(@root, resolved_path))
        )
      end

      sig { params(path: String, source_path: String).returns(String) }
      def resolve_path(path, source_path = "/")
        full_path = File.expand_path(path, File.dirname(source_path))

        if File.file?(File.join(@root, full_path))
          full_path
        else
          full_path.sub(/(.rux)?$/, ".rux")
        end
      end

      sig do
        params(path: String).returns(CSS::Base)
      end
      def load_css(path)
        CSS.load(
          File.join(@root, resolve_path(path.sub(/\.rux$/, ".css")))
        )
      end
    end
  end
end
