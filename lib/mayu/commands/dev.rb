# typed: strict
# frozen_string_literal: true

require_relative "base"
require_relative "../server"

module Mayu
  module Commands
    class Dev < Base
      extend T::Sig

      sig { params(argv: T::Array[String]).void }
      def call(argv)
        Configuration.log_config(configuration)
        Server.start_dev(configuration)
      end
    end
  end
end
