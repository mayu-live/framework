# typed: strict

require_relative "types"
require_relative "router"
require_relative "env_inspector"

module Mayu
  module Server
    class App
      Types = Mayu::Server::Types

      extend T::Sig

      sig {params(app: Types::TRackApp).void}
      def initialize(app)
        @app = T.let(app, Types::TRackApp)
      end

      sig {params(env: Types::TRackHeaders).returns(Types::TRackReturn)}
      def call(env)
        Mayu::Server::EnvInspector.new.inspect_env(env)

        handle_request(env) || @app.call(env)
      end

      sig {returns(String)}
      def build_response
        "hello"
      end

      private

      sig {params(env: Types::TRackHeaders).returns(T.nilable(Types::TRackReturn))}
      def handle_request(env)
        case env["PATH_INFO"].to_s.split("/")
        end
        [200, {}, [build_response]]
      end
    end
  end
end
