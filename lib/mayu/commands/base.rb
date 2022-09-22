# typed: strict
# frozen_string_literal: true

module Mayu
  module Commands
    class Base
      extend T::Sig

      sig { returns(Configuration) }
      attr_reader :configuration

      sig { params(configuration: Configuration).void }
      def initialize(configuration)
        @configuration = configuration
      end

      sig { params(argv: T::Array[String]).void }
      def call(argv)
      end
    end
  end
end
