# typed: strict

require_relative "../vdom/component"
require_relative "rux_visitor"

module Mayu
  module Modules
    class ComponentModule
      module MODULES
      end

      extend T::Sig

      sig { returns(T.class_of(VDOM::Component::Base)) }
      attr_reader :klass

      sig do
        params(
          system: Modules::System,
          path: String,
          full_path: String,
          source: String
        ).void
      end
      def initialize(system, path, full_path, source)
        if path.end_with?(".mayu")
          source = Rux.to_ruby(source, visitor: RuxVisitor.new)
        end

        @klass =
          T.let(
            T.cast(
              Class.new(VDOM::Component::Base),
              T.class_of(VDOM::Component::Base)
            ),
            T.class_of(VDOM::Component::Base)
          )

        @klass.const_set(:MAYU_MODULE, { system:, path:, full_path: })

        MODULES.const_set(
          "MOD_#{Digest::SHA256.hexdigest(full_path)}".to_sym,
          @klass
        )

        @klass.class_eval do
          define_method :__mayu_module do
            self.const_get(:MAYU_MODULE)
          end
        end

        @klass.const_set(:CSS, system.load_css(full_path))
        @klass.class_eval(source, full_path, 0)
      end
    end
  end
end
