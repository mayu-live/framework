# typed: strict

require_relative "markup/builder"

module Mayu
  module Markup
    extend T::Sig

    sig do
      params(block: T.nilable(T.proc.bind(Builder).void)).returns(T.nilable(VDOM::Descriptor))
    end
    def self.build(&block)
      Builder.new.capture(&block).first
    end
  end
end
