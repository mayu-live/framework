# typed: strict

require_relative "../vdom/component"
require_relative "rux_visitor"

module Mayu
  module Modules
    class ComponentModule
      extend T::Sig

      sig { returns(T.class_of(VDOM::Component::Base)) }
      attr_reader :klass

      sig { params(system: Modules::System, path: String, source: String).void }
      def initialize(system, path, source)
        transpiled = Rux.to_ruby(source, visitor: RuxVisitor.new)

        @klass =
          T.let(
            T.cast(
              Class.new(VDOM::Component::Base),
              T.class_of(VDOM::Component::Base)
            ),
            T.class_of(VDOM::Component::Base)
          )

        @klass.const_set(:MAYU_MODULE, { system:, path: })

        @klass.class_eval do
          define_method :__mayu_module do
            self.const_get(:MAYU_MODULE)
          end
        end

        @klass.const_set(:CSS, system.load_css(path))
        @klass.class_eval(transpiled, path, 0)
      end
    end
  end
end
