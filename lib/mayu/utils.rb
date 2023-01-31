# typed: strict

module Mayu
  module Utils
    extend T::Sig

    sig { params(unit: Symbol).returns(Float) }
    def self.monotonic_now(unit = :float_millisecond)
      Process.clock_gettime(Process::CLOCK_MONOTONIC, unit).to_f
    end

    sig { params(unit: Symbol, block: T.proc.void).returns(Float) }
    def self.measure_time(unit = :float_millisecond, &block)
      start = monotonic_now
      yield
      monotonic_now - start
    end

    sig do
      params(
        hash: T::Hash[T.untyped, T.untyped],
        path: T::Array[String]
      ).returns(T::Hash[Symbol, T.untyped])
    end
    def self.flatten_props(hash, path = [])
      hash.reduce({}) do |obj, (k, v)|
        next obj.merge(style: v) if k == :style && path.empty?

        current_path = [*path, k]

        obj.merge(
          case v
          when Hash
            flatten_props(v, current_path)
          else
            { current_path.join("_").to_sym => v }
          end
        )
      end
    end

    class DeepFreezer
      extend T::Sig
      extend T::Generic
      Elem = type_member { { upper: Object } }

      sig { params(obj: Elem).void }
      def initialize(obj) = @obj = obj

      sig { returns(Elem) }
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
      Elem = type_member { { upper: Object } }

      sig { params(obj: Elem).void }
      def initialize(obj) = @obj = obj

      sig { returns(Elem) }
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
