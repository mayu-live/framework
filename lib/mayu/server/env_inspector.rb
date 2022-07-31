# typed: strict

require_relative "types"

class Mayu::Server::EnvInspector
  extend T::Sig

  Types = Mayu::Server::Types

  TPairs =
    T.type_alias { T.any(Types::TRackHeaders, T::Array[[String, String]]) }

  sig { params(env: Types::TRackHeaders).void }
  def inspect_env(env)
    puts format("Request headers", request_headers(env))
    puts format("Server info", server_info(env))
    puts format("Rack info", rack_info(env))
  end

  sig { params(env: Types::TRackHeaders).returns(TPairs) }
  def request_headers(env)
    env.select { |key, value| key.include?("HTTP_") }
  end

  sig { params(env: Types::TRackHeaders).returns(TPairs) }
  def server_info(env)
    env.reject { |key, value| key.include?("HTTP_") or key.include?("rack.") }
  end

  sig { params(env: Types::TRackHeaders).returns(TPairs) }
  def rack_info(env)
    env.select { |key, value| key.include?("rack.") }
  end

  sig { params(heading: String, pairs: TPairs).returns(String) }
  def format(heading, pairs)
    [heading, "", format_pairs(pairs), "\n"].join("\n")
  end

  sig { params(pairs: TPairs).returns(T::Array[String]) }
  def format_pairs(pairs)
    pairs.map { |key, value| "  " + [key, value.inspect].join(": ") }
  end
end
