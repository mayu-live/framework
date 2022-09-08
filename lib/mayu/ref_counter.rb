# typed: strict

module Mayu
  class RefCounter
    extend T::Sig
    extend T::Generic

    Elem = type_member

    sig { void }
    def initialize
      @refs = T.let(Hash.new { |h, k| h[k] = 0 }, T::Hash[Elem, Integer])
    end

    sig { returns(T::Array[Elem]) }
    def keys
      @refs.sort_by { _2 }.map(&:first)
    end

    sig do
      type_parameters(:R)
        .params(
          key: Elem,
          block: T.nilable(T.proc.returns(T.type_parameter(:R)))
        )
        .returns(T.type_parameter(:R))
    end
    def acquire(key, &block)
      @refs[key] += 1

      return unless block_given?

      begin
        return yield
      ensure
        release(key)
      end
    end

    sig { params(key: Elem).void }
    def release(key)
      count = @refs.fetch(key, nil)
      return unless count

      if count > 1
        @refs[key] = count
      else
        @refs.delete(key)
      end
    end
  end
end
