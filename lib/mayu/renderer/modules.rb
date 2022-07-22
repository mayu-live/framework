# typed: strict

require_relative "rux_visitor"
require_relative "component_builder"
require_relative "css_module"
require_relative "vdom"

module Mayu
  module Renderer
    class Modules
      extend T::Sig

      sig {params(root: String).void}
      def initialize(root)
        @root = root
      end

      sig {params(path: String, source_path: String).returns(T.class_of(VDOM::Component))}
      def load_component(path, source_path = "/")
        path = resolve_path(path, source_path)
        source = File.read(File.join(@root, path))
        transpiled = Rux.to_ruby(source, visitor: RuxVisitor.new)

        klass = T.cast(Class.new(VDOM::Component), T.class_of(VDOM::Component))
        klass.class_eval do
          define_method :inspect do
            "hello"
          end
        end
        klass.const_set(:MODULES, self)
        klass.const_set(:MODULE_PATH, path)
        css = load_css(File.join(@root, path))
        klass.const_set(:CSS, css)
        klass.class_eval(transpiled)
        klass
      end

      sig {params(path: String, source_path: String).returns(String)}
      def resolve_path(path, source_path = "/")
        File
          .expand_path(path, File.dirname(source_path))
          .sub(/(.rux)?$/, ".rux")
      end

      sig {params(path: String).returns(T.any(CSSModule, CSSModule::NoModule))}
      def load_css(path)
        CSSModule.load(path.sub(/\.rux$/, ".css"))
      end
    end
  end
end
