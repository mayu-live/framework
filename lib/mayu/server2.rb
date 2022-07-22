# typed: true

require 'rack'
require 'cgi'

class Mayu::Server2
  extend T::Sig

  TRackEnv = T.type_alias { T::Hash[String, String] }

  TRackReturn = T.type_alias do
    T.any(
      [Integer, TRackEnv, T::Array[String]],
      [Integer, Array, Array],
    )
  end

  TRackApp = T.type_alias {
    T.proc.params(arg0: TRackEnv).returns([Integer, TRackEnv, Array])
  }

  sig {params(app: TRackApp).void}
  def initialize(app)
    @app = T.let(app, TRackApp)
  end

  sig {params(env: TRackEnv).returns(TRackReturn)}
  def call(env)
    if env["PATH_INFO"] == "/hello"
      [200, {}, [print_response]]
    else
      @app.call(env)
    end
  end

  sig {returns(String)}
  def print_response
    "hello"
  end
end
