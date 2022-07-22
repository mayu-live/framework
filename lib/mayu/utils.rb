# typed: strict

module Mayu
  module Utils
    extend T::Sig

    class DeepFreezer
      extend T::Sig
      extend T::Generic
      Elem = type_member {{upper: Object}}

      sig {params(obj: Elem).void}
      def initialize(obj) = @obj = obj

      sig {returns(Elem)}
      def deep_freeze
        case @obj
        when Hash
          @obj.freeze
          T.cast(
            @obj
              .transform_keys { Utils.deep_freeze(_1) }
              .transform_values { Utils.deep_freeze(_1) },
            Elem
          )
        when Array
          T.cast(@obj.map(&:freeze), Elem)
        else
          @obj.freeze
        end
      end
    end

    class DeepDuper
      extend T::Sig
      extend T::Generic
      Elem = type_member {{upper: Object}}

      sig {params(obj: Elem).void}
      def initialize(obj) = @obj = obj

      sig {returns(Elem)}
      def deep_dup
        case @obj
        when Hash
          @obj.dup
          T.cast(
            @obj
              .transform_keys { Utils.deep_dup(_1) }
              .transform_values { Utils.deep_dup(_1) },
            Elem
          )
        when Array
          T.cast(@obj.map(&:dup), Elem)
        else
          @obj.dup
        end
      end
    end

    sig do
      type_parameters(:O)
        .params(obj: T.type_parameter(:O))
        .returns(T.type_parameter(:O))
    end
    def self.deep_freeze(obj)
      DeepFreezer.new(obj).deep_freeze
    end

    sig do
      type_parameters(:O)
        .params(obj: T.type_parameter(:O))
        .returns(T.type_parameter(:O))
    end
    def self.deep_dup(obj)
      DeepDuper.new(obj).deep_dup
    end
  end
end
