# typed: strict

module Mayu
  module Markup
    class UnclosedElement < BasicObject
      extend ::T::Sig

      sig {params(descriptor: ::Mayu::VDOM::Descriptor).void}
      def initialize(descriptor)
        @descriptor = descriptor
      end

      sig {params(klass: ::T.untyped).returns(::T::Boolean)}
      def is_a?(klass)
        ::Object.instance_method(:is_a?).bind(self).call(klass)
      end
    end
  end
end
