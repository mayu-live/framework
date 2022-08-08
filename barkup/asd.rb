# typed: strict

module Asdlol
  extend T::Sig

  sig { void }
  def asd
  end

  sig { void }
  def main
    asd
  end
end

extend Asdlol

main
