# typed: strict

module Mayu
  module State
    class ActionWrapper
      extend T::Sig

      sig { returns(Symbol) }
      attr_reader :type
      sig { returns(T.untyped) }
      attr_reader :payload

      sig { params(type: Symbol, payload: T.untyped).void }
      def initialize(type:, payload:)
        @type = type
        @payload = payload
      end

      sig { params(key: T.untyped).returns(T.untyped) }
      def [](key) = @payload[key]
      sig { params(key: T.untyped, block: T.untyped).returns(T.untyped) }
      def fetch(key, &block) = @payload.fetch(key, &block)

      sig { returns(String) }
      def inspect
        "#<Action/#{type} payload=#{payload.inspect}>"
      end
    end
  end
end
