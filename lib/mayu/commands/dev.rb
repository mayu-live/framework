# typed: strict
# frozen_string_literal: true

require_relative "base"
require_relative "../server2"

module Mayu
  module Commands
    class Dev < Base
      extend T::Sig

      sig { params(argv: T::Array[String]).void }
      def call(argv)
        Configuration.log_config(configuration)
        Server2.start_dev(configuration).wait
      end
    end
  end
end
