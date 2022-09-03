# typed: strict

module Mayu
  module Component
    extend T::Sig

    Props = T.type_alias { T::Hash[Symbol, T.untyped] }
    State = T.type_alias { T::Hash[String, T.untyped] }

    sig { params(klass: T.untyped).returns(T::Boolean) }
    def self.component_class?(klass)
      !!(klass.is_a?(Class) && klass < Base)
    end
  end
end
