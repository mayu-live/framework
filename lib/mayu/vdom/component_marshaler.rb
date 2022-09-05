require_relative "../component"

module Mayu
  module VDOM
    class ComponentMarshaler
      extend T::Sig

      sig { returns(T.untyped) }
      attr_reader :type

      sig { params(type: T.untyped).void }
      def initialize(type)
        @type =
          T.let(
            if Component.component_class?(type)
              klass = T.cast(type, T.class_of(Component::Base))

              if klass.name
                { klass: klass }
              else
                component = klass.__mayu_resource.path
                { component: }
              end
            else
              type
            end,
            T.untyped
          )
      end

      sig { returns(T.untyped) }
      def marshal_dump
        @type
      end

      sig { params(a: T.untyped).void }
      def marshal_load(a)
        @type = a
      end
    end
  end
end
