# typed: strict

require_relative "base"

module Mayu
  module Component
    class HandlerRef
      extend T::Sig

      sig { returns(String) }
      attr_reader :id

      sig do
        params(
          component: Base,
          name: Symbol,
          args: T::Array[T.untyped],
          kwargs: T::Hash[Symbol, T.untyped]
        ).void
      end
      def initialize(component, name, args = [], kwargs = {})
        @component = component
        @name = name
        # TODO: Validate args
        # method = T.let(component.method(name), T.untyped)
        @args = args
        @kwargs = kwargs
        @id =
          T.let(
            Digest::SHA256.hexdigest(
              [component.vnode_id, name, @args, @kwargs].map do
                  Digest::SHA256.digest(_1.inspect)
                end
                .join
            ),
            String
          )
      end

      sig { params(payload: T.untyped).void }
      def call(payload)
        @component.send(@name, payload, *@args, **@kwargs)
      end

      sig { returns(String) }
      def to_s
        "Mayu.handle(event,'#{@id}')"
      end

      sig { params(other: HandlerRef).returns(T::Boolean) }
      def ==(other)
        @id == other.id
      end
    end
  end
end
