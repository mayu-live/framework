# typed: strict
# frozen_string_literal: true

require_relative "base"

module Mayu
  module Commands
    class Build < Base
      extend T::Sig

      sig { params(argv: T::Array[String]).void }
      def call(argv)
      end
    end
  end
end
