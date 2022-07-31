# typed: strict

require_relative "types"

module Mayu
  module Server
    class Router
      extend T::Sig
      Types = Mayu::Server::Types

      sig { params(app: Types::TRackApp).void }
      def initialize(app)
        @app = app
      end
    end
  end
end
