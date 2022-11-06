# typed: strict

require_relative "vdom/h"

module Mayu
  module VDOM
    extend T::Sig
    extend VDOM::H

    sig do
      params(children: T::Array[Descriptor]).returns(
        T::Hash[T.nilable(String), Descriptor]
      )
    end
    def self.slots(children)
      T.cast(children.group_by(&:slot), T::Hash[T.nilable(String), Descriptor])
    end

    sig do
      params(children: T::Array[Descriptor], name: T.nilable(String)).returns(
        T::Array[Descriptor]
      )
    end
    def self.slot(children, name = nil)
      children.select { _1.slot == name }
    end
  end
end
