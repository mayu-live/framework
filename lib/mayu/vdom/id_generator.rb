# typed: strict

module Mayu
  module VDOM
    class IdGenerator
      extend T::Sig

      ALPHABET = "🌱🌴🌵🌸🌺🌻🌼🌿🍀🍃"
      JOINER = " "
      # ALPHABET = "0123456789"
      # JOINER = ""

      DIGITS = T.let(ALPHABET.chars.freeze, T::Array[String])

      Type = T.type_alias { String }

      sig { void }
      def initialize
        @counter = T.let(0, Integer)
      end

      sig { returns(Type) }
      def next!
        id = @counter.tap { @counter = @counter.succ }
        number_to_base(id, DIGITS.length).map { DIGITS[_1] }.join(JOINER)
      end

      private

      sig { params(number: Integer, base: Integer).returns(T::Array[Integer]) }
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
