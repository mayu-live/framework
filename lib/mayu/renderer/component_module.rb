# typed: strict

require_relative "rux_visitor"
require_relative "component"
require_relative "css_module"
require_relative "vdom"

module Mayu
  module Renderer
    class ComponentModule
      extend T::Sig

      ROOT = T.let(File.join(File.dirname(__FILE__), "components"), String)

      sig {params(path: String, source_path: String).returns(T.class_of(VDOM::Component))}
      def self.load(path, source_path = "/")
        path = resolve_path(path, source_path)
        source = File.read(File.join(ROOT, path))
        transpiled = Rux.to_ruby(source, visitor: RuxVisitor.new)

        klass = T.cast(Class.new(VDOM::Component), T.class_of(VDOM::Component))
        klass.const_set(:MODULE_PATH, path)
        css = load_css(File.join(ROOT, path))
        klass.const_set(:CSS, css)
        klass.class_eval(transpiled)
        klass
      end

      sig {params(path: String, source_path: String).returns(String)}
      def self.resolve_path(path, source_path = "/")
        File
          .expand_path(path, File.dirname(source_path))
          .sub(/(.rux)?$/, ".rux")
      end

      sig {params(path: String).returns(String)}
      def self.load_css(path)
        CSSModule.load(path.sub(/\.rux$/, ".css"))
      end
    end
  end
end
