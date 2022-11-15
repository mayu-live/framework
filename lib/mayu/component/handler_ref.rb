# typed: strict

require_relative "base"

module Mayu
  module Component
    class HandlerRef
      extend T::Sig

      ID_LENGTH = 16
      ID_FORMAT = /\A[[:graph:]]{#{ID_LENGTH}}\z/

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
        @args = args
        @kwargs = kwargs
        # TODO: Validate that args and kwargs match the method signature.
        method = T.let(component.public_method(name), Method)
        @arity = T.let(method.arity, Integer)
        @id =
          T.let(
            [component.vnode_id, name, @args, @kwargs].inspect
              .then { Digest::SHA256.digest(_1) }
              .then { Base64.urlsafe_encode64(_1) }
              .then { _1[0, ID_LENGTH] },
            String
          )
      end

      sig { returns(String) }
      def inspect
        "#<HandlerRef vnode_id=%d %s(%s)" %
          [
            @component.vnode_id,
            @name,
            [*@args.map(&:inspect), *@kwargs.inspect].join(", ")
          ]
      end

      sig { params(args: T.untyped, kwargs: T.untyped).returns(HandlerRef) }
      def bind_args(*args, **kwargs)
        self.class.new(
          @component,
          @name,
          [*@args, *args],
          { **@kwargs, **kwargs }
        )
      end

      sig { void }
      def marshal_dump
        []
      end

      sig { params(a: T.untyped).void }
      def marshal_load(a)
        @id = "invalid"
      end

      sig { params(payload: T.untyped).void }
      def call(payload)
        if @arity.zero?
          T.unsafe(@component).public_send(@name)
        else
          T.unsafe(@component).public_send(@name, payload, *@args, **@kwargs)
        end
      end

      sig { returns(String) }
      def to_s
        "Mayu.handle(event,'#{@id}')"
      end

      sig { params(other: T.untyped).returns(T::Boolean) }
      def ==(other)
        self.class === other && @id == other.id
      end
    end
  end
end
