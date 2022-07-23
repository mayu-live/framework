# typed: strict

require_relative "vdom"

module Mayu
  module Renderer
    class ComponentModule
      extend T::Sig

      sig {returns(T.class_of(VDOM::Component))}
      attr_reader :klass

      sig {params(modules: Modules, path: String, source: String).void}
      def initialize(modules, path, source)
        transpiled = Rux.to_ruby(source, visitor: RuxVisitor.new)

        @klass = T.let(
          T.cast(Class.new(VDOM::Component), T.class_of(VDOM::Component)),
          T.class_of(VDOM::Component)
        )

        @klass.class_eval do
          define_method :inspect do
            "hello"
          end
        end

        @klass.const_set(:MODULES, modules)
        @klass.const_set(:MODULE_PATH, path)
        css = modules.load_css(path)
        @klass.const_set(:CSS, css)
        @klass.class_eval(transpiled, path, 0)
      end
    end
  end
end
