# typed: strict

require_relative "vdom/h"

module Mayu
  module VDOM
    extend T::Sig
    extend VDOM::H

    sig do
      params(children: T::Array[Descriptor], name: T.nilable(String)).returns(
        T.nilable(T::Array[Descriptor])
      )
    end
    def self.slot(children, name = nil)
      children.select { _1.props[:slot] == name }
    end
  end
end
