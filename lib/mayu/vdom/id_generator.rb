# typed: strict

module Mayu
  module VDOM
    class IdGenerator
      extend T::Sig

      EMOJIS = T.let(
        "🌱🌴🌵🌸🌺🌻🌼🌿🍀🍃".chars,
        T::Array[String]
      )

      Type = T.type_alias { String }

      sig {void}
      def initialize
        @counter = T.let(0, Integer)
      end

      sig {returns(Type)}
      def next!
        id = @counter.tap { @counter = @counter.succ }
        number_to_base(id, EMOJIS.length).map { EMOJIS[_1] }.join(" ")
      end

      private

      sig {params(number: Integer, base: Integer).returns(T::Array[Integer])}
      def number_to_base(number, base)
        return [0] if number.zero?

        digits = []

        until number.zero?
          digits.unshift(number % base)
          number /= base
        end

        digits
      end
    end
  end
end