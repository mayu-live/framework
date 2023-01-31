# typed: strict

class Fiber
  class << self
    extend T::Sig

    sig {params(key: T.any(String, Symbol)).returns(T.untyped)}
    def [](key)
    end

    sig {params(key: T.any(String, Symbol), value: T.untyped).void}
    def []=(key, value)
    end
  end
end
