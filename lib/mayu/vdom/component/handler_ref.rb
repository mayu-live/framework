# typed: strict

require_relative "../component"
require_relative "base"

module Mayu
  module VDOM
    module Component
      class HandlerRef
        extend T::Sig

        sig { returns(String) }
        attr_reader :id

        sig do
          params(
            component: Component::Base,
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
          @id =
            T.let(
              Digest::SHA256.hexdigest(
                [@component.vnode_id, @name, @args, @kwargs].map(
                  &:inspect
                ).join(":")
              ),
              String
            )
        end

        sig { params(payload: T.untyped).void }
        def call(payload)
          method = @component.method(:"handle_#{@name}")
          T.unsafe(method).call(
            *[payload, *@args, **@kwargs].first(method.arity)
          )
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
end
