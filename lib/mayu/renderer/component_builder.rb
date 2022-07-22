# typed: strict

require_relative "vdom"

module Mayu
  module Renderer
    class ComponentBuilder
      extend T::Sig

      sig {void}
      def initialize
        @klass = T.let(
          T.cast(Class.new(VDOM::Component), T.class_of(VDOM::Component)),
          T.class_of(VDOM::Component)
        )
      end

      sig {params(block: T.proc.returns(VDOM::Descriptor::Children)).returns(self)}
      def render(&block)
        @klass.define_method(:render, &block)
        self
      end

      sig {params(block: T.proc.void).returns(self)}
      def did_mount(&block)
        @klass.define_method(:did_mount, &block)
        self
      end

      sig {params(block: T.proc.void).returns(self)}
      def will_unmount(&block)
        @klass.define_method(:will_unmount, &block)
        self
      end

      sig {params(block: T.proc.params(next_props: VDOM::Props, next_state: VDOM::State).returns(T::Boolean)).returns(self)}
      def should_update?(&block)
        @klass.define_method(:should_update?, &block)
        self
      end

      sig {params(block: T.proc.void).returns(self)}
      def did_mount(&block)
        @klass.define_method(:did_mount, &block)
        self
      end

      sig {returns(T.class_of(VDOM::Component))}
      def final!
        @klass
      end
    end
  end
end
